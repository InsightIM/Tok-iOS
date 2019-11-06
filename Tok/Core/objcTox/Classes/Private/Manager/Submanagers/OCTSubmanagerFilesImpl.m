// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerFilesImpl.h"
#import "OCTSubmanagerFilesProgressSubscriber.h"
#import "OCTTox.h"
#import "OCTToxConstants.h"
#import "OCTFileDownloadOperation.h"
#import "OCTFileUploadOperation.h"
#import "OCTFileBaseOperation+Private.h"
#import "OCTRealmManager.h"
#import "OCTLogging.h"
#import "OCTMessageAbstract.h"
#import "OCTMessageFile.h"
#import "OCTFriend.h"
#import "OCTChat.h"
#import "OCTFileStorageProtocol.h"
#import "OCTFilePathInput.h"
#import "OCTFilePathOutput.h"
#import "OCTFileDataInput.h"
#import "OCTFileDataOutput.h"
#import "OCTFileTools.h"
#import "OCTSettingsStorageObject.h"
#import "NSError+OCTFile.h"
#import "Message.pbobjc.h"
#import "OCTSendGroupMessageOperation.h"
#import "OCTSendOfflineMessageOperation.h"

#if TARGET_OS_IPHONE
@import MobileCoreServices;
#endif

static NSString *const kDownloadsTempDirectory = @"files";

static NSString *const kProgressSubscribersKey = @"kProgressSubscribersKey";
static NSString *const kMessageIdentifierKey = @"kMessageIdentifierKey";
static NSString *const kMessageIsGroupKey = @"kMessageIsGroupKey";
static NSString *const kMessageGroupNumberKey = @"kMessageGroupNumberKey";
static NSString *const kMessageToFriendPKKey = @"kMessageToFriendPKKey";

@interface OCTSubmanagerFilesImpl ()

@property (strong, nonatomic, readonly) NSOperationQueue *queue;

@property (strong, nonatomic, readonly) NSMutableArray<OCTFileUploadOperation *> *uploadQueue;
@property (strong, nonatomic, readonly) NSMutableArray<OCTFileDownloadOperation *> *downloadQueue;
@property (strong, nonatomic, readonly) NSObject *uploadLock;
@property (strong, nonatomic, readonly) NSObject *downloadLock;

@property (strong, nonatomic, readonly) NSObject *filesCleanupLock;
@property (assign, nonatomic) BOOL filesCleanupInProgress;

@end

@implementation OCTSubmanagerFilesImpl
@synthesize dataSource = _dataSource;

#pragma mark -  Lifecycle

- (instancetype)init
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _queue = [NSOperationQueue new];
    _filesCleanupLock = [NSObject new];
    
    _uploadQueue = @[].mutableCopy;
    _downloadQueue = @[].mutableCopy;
    _uploadLock = [NSObject new];
    _downloadLock = [NSObject new];
    
    return self;
}

- (void)dealloc
{
    [self.dataSource.managerGetNotificationCenter removeObserver:self];
}

- (void)configure
{
    [self.dataSource.managerGetNotificationCenter addObserver:self
                                                     selector:@selector(friendConnectionStatusChangeNotification:)
                                                         name:kOCTFriendConnectionStatusChangeNotification
                                                       object:nil];
    [self.dataSource.managerGetNotificationCenter addObserver:self
                                                     selector:@selector(userAvatarWasUpdatedNotification)
                                                         name:kOCTUserAvatarWasUpdatedNotification
                                                       object:nil];
    [self.dataSource.managerGetNotificationCenter addObserver:self
                                                     selector:@selector(scheduleFilesCleanup)
                                                         name:kOCTScheduleFileTransferCleanupNotification
                                                       object:nil];
    [self.dataSource.managerGetNotificationCenter addObserver:self
                                                     selector:@selector(receivedBotFileMessageNotification:)
                                                         name:kOCTBotFileMessageReceivedNotification
                                                       object:nil];

    OCTLogInfo(@"cancelling pending files...");
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"fileType == %d OR fileType == %d OR fileType == %d",
                              OCTMessageFileTypeWaitingConfirmation, OCTMessageFileTypeLoading, OCTMessageFileTypePaused];

    [realmManager updateObjectsWithClass:[OCTMessageFile class] predicate:predicate updateBlock:^(OCTMessageFile *file) {
        file.fileType = OCTMessageFileTypeCanceled;
        OCTLogInfo(@"cancelling file %@", file);
    }];

    OCTLogInfo(@"cancelling pending files... done");

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *downloads = [self downloadsTempDirectory];
    OCTLogInfo(@"clearing downloads temp directory %@\ncontents %@",
               downloads,
               [fileManager contentsOfDirectoryAtPath:downloads error:nil]);
    [fileManager removeItemAtPath:downloads error:nil];

//    [self scheduleFilesCleanup];
}

- (void)addOperation:(OCTFileBaseOperation *)operation
{
    if ([operation isKindOfClass:[OCTFileUploadOperation class]]) {
        @synchronized (self.uploadLock) {
            [self.uploadQueue addObject:(OCTFileUploadOperation *)operation];
        }
        [self startNextUploadOperation];
    } else if ([operation isKindOfClass:[OCTFileDownloadOperation class]]) {
        @synchronized (self.downloadLock) {
            [self.downloadQueue addObject:(OCTFileDownloadOperation *)operation];
        }
        [self startNextDownloadOperation];
    }

    [operation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];
    [operation addObserver:self forKeyPath:@"isCancelled" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removeOperation:(OCTFileBaseOperation *)operation
{
    if ([operation isKindOfClass:[OCTFileUploadOperation class]]) {
        @synchronized (self.uploadLock) {
            [self.uploadQueue removeObject:(OCTFileUploadOperation *)operation];
        }
        [self startNextUploadOperation];
    } else if ([operation isKindOfClass:[OCTFileDownloadOperation class]]) {
        @synchronized (self.downloadLock) {
            [self.downloadQueue removeObject:(OCTFileDownloadOperation *)operation];
        }
        [self startNextDownloadOperation];
    }
}

- (void)startNextUploadOperation {
    for (OCTFileBaseOperation *operation in self.uploadQueue) {
        if (operation.isExecuting) {
            return;
        }
    }
    
    OCTFileUploadOperation *operation = self.uploadQueue.firstObject;
    
    NSString *identifier = operation.userInfo[kMessageIdentifierKey];
    OCTMessageAbstract *message;
    
    if (identifier) {
        message = [self.dataSource.managerGetRealmManager objectWithUniqueIdentifier:identifier
                                                                               class:[OCTMessageAbstract class]];
    }
    
    if (message == nil) {
        [self removeOperation:operation];
        return;
    }
    
    NSString *fileName = message.messageFile.fileName;
    NSData *realName;
    if (message.messageFile.isOffline) {
        NSNumber *isGroup = operation.userInfo[kMessageIsGroupKey];
        
        FileTransfer *transfer = [FileTransfer new];
        transfer.msgId = message.messageFile.messageId;
        transfer.realName = [fileName dataUsingEncoding:NSUTF8StringEncoding];
        if (isGroup.boolValue) {
            NSNumber *groupNumber = operation.userInfo[kMessageGroupNumberKey];
            transfer.groupId = groupNumber.integerValue;
        } else {
            NSString *publicKey = operation.userInfo[kMessageToFriendPKKey];
            transfer.toPk = [publicKey.uppercaseString dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        realName = [transfer data];
    } else {
        realName = [fileName dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSError *error;
    OCTToxFileNumber fileNumber = [[self.dataSource managerGetTox] fileSendWithFriendNumber:operation.friendNumber
                                                                                       kind:OCTToxFileKindData
                                                                                   fileSize:operation.fileSize
                                                                                     fileId:nil
                                                                                   fileName:realName
                                                                                      error:&error];
    
    if (fileNumber == kOCTToxFileNumberFailure) {
        OCTLogWarn(@"cannot send file %@", error);
        [self removeOperation:operation];
        return;
    }
    
    operation.fileNumber = fileNumber;
    [[self.dataSource managerGetRealmManager] updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.messageFile.internalFileNumber = fileNumber;
    }];
    
    [self.uploadQueue.firstObject start];
}

- (void)startNextDownloadOperation {
    for (OCTFileBaseOperation *operation in self.downloadQueue) {
        if (operation.isExecuting) {
            OCTLogDebug(@"Download operation.isExecuting");
            return;
        }
    }
    
    [self.downloadQueue.firstObject start];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"isFinished"]) {
        id isFinished = [change objectForKey:NSKeyValueChangeNewKey];
        if ([isFinished boolValue]) {
            if ([object isKindOfClass:[OCTFileBaseOperation class]]) {
                [self removeOperation:(OCTFileBaseOperation *)object];
                [object removeObserver:self forKeyPath:@"isFinished"];
            }
        }
    } else if ([keyPath isEqualToString:@"isCancelled"]) {
        id isCancelled = [change objectForKey:NSKeyValueChangeNewKey];
        if ([isCancelled boolValue]) {
            if ([object isKindOfClass:[OCTFileBaseOperation class]]) {
                [self cancelFileTransfer:(OCTFileBaseOperation *)object];
                [object removeObserver:self forKeyPath:@"isCancelled"];
            }
        }
    }
}

- (BOOL)cancelFileTransfer:(OCTFileBaseOperation *)operation
{
    NSString *identifier = operation.userInfo[kMessageIdentifierKey];
    OCTMessageAbstract *message;
    
    if (identifier) {
        message = [self.dataSource.managerGetRealmManager objectWithUniqueIdentifier:identifier
                                                                               class:[OCTMessageAbstract class]];
    }
    
    if (message == nil) {
        return NO;
    }
    
    if (! message.messageFile) {
        OCTLogWarn(@"specified wrong message: no messageFile. %@", message);
        return NO;
    }
    
    OCTFriend *friend = [self friendForMessage:message];
    OCTToxFriendNumber friendNumber = friend.friendNumber;
    
    [self.dataSource.managerGetTox fileSendControlForFileNumber:message.messageFile.internalFileNumber
                                                   friendNumber:friendNumber
                                                        control:OCTToxFileControlCancel
                                                          error:nil];
    
    [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
        file.fileType = OCTMessageFileTypeCanceled;
    }];
    
    return YES;
}

#pragma mark -  Public

- (void)sendData:(nonnull NSData *)data
    withFileName:(nonnull NSString *)fileName
          toChat:(nonnull OCTChat *)chat
    failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock
{
    NSParameterAssert(data);
    NSParameterAssert(fileName);
    NSParameterAssert(chat);

    NSString *uniqueName = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:fileName.pathExtension];
    NSString *filePath = [OCTFileTools createNewFilePathInDirectory:[self uploadsDirectory] fileName:uniqueName];

    if (! [data writeToFile:filePath atomically:NO]) {
        OCTLogWarn(@"cannot save data to uploads directory.");
        if (failureBlock) {
            failureBlock([NSError sendFileErrorCannotSaveFileToUploads]);
        }
        return;
    }

    [self sendFileAtPath:filePath fileName:fileName moveToUploads:NO toChat:chat failureBlock:failureBlock];
}

- (void)sendFileAtPath:(nonnull NSString *)filePath
              fileName:(NSString *)fileName
         moveToUploads:(BOOL)moveToUploads
                toChat:(nonnull OCTChat *)chat
          failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock
{
    NSParameterAssert(filePath);
    NSParameterAssert(chat);

    OCTToxMessageId messageId = [[self.dataSource managerGetTox] generateMessageId];
    void (^commonFailureBlock)(NSString *, OCTToxFileSize, NSString*, NSError *) = ^(NSString *fileName, OCTToxFileSize fileSize, NSString *filePath, NSError *error){
        OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
        [realmManager addMessageWithFileNumber:UINT32_MAX
                                      fileType:OCTMessageFileTypeCanceled
                                      fileSize:fileSize
                                      fileName:fileName
                                      filePath:filePath
                                       fileUTI:[self fileUTIFromFileName:fileName]
                                          chat:chat
                                        sender:nil
                                  dateInterval:0
                                     isOffline:NO
                                     messageId:messageId
                                        opened:YES];
        
        if (failureBlock) {
            failureBlock(error);
        }
    };
    
    NSError *error;

    if (moveToUploads) {
        NSString *uniqueName = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:fileName.pathExtension];
        NSString *toPath = [[self uploadsDirectory] stringByAppendingPathComponent:uniqueName];

        if (error) {
            OCTLogError(@"cannot move file to uploads %@", error);
            commonFailureBlock(fileName, 0, filePath, [NSError sendFileErrorCannotSaveFileToUploads]);
            return;
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            OCTLogError(@"cannot move file to uploads %@", error);
            commonFailureBlock(fileName, 0, filePath, [NSError sendFileErrorCannotSaveFileToUploads]);
            return;
        }
        
        if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:toPath error:&error]) {
            OCTLogError(@"cannot move file to uploads %@", error);
            commonFailureBlock(fileName, 0, filePath, [NSError sendFileErrorCannotSaveFileToUploads]);
            return;
        }

        filePath = toPath;
    }

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];

    if (! attributes) {
        OCTLogWarn(@"cannot read file %@", filePath);
        commonFailureBlock(fileName, 0, filePath, [NSError sendFileErrorCannotReadFile]);
        return;
    }
    
    OCTToxFileSize fileSize = [attributes[NSFileSize] longLongValue];
    
    OCTFriend *friend = [chat.friends firstObject];
    OCTToxFriendNumber friendID = friend.friendNumber;

    BOOL isToBot = NO;
    if (chat.isGroup) {
        isToBot = YES;
        OCTFriend *bot = [self groupBot];
        if (bot.isConnected == NO) {
            commonFailureBlock(fileName, fileSize, filePath, [NSError sendFileErrorFriendNotConnected]);
            return;
        }
        
        friendID = bot.friendNumber;
    } else if (friend.isConnected == NO) {
        isToBot = YES;
        OCTFriend *bot = [self offlineBot];
        if (bot.isConnected == NO) {
            commonFailureBlock(fileName, fileSize, filePath, [NSError sendFileErrorFriendNotConnected]);
            return;
        }
        
        friendID = bot.friendNumber;
    }
    
    if (isToBot) {
        if (fileSize > kOCTManagerMaxOfflineFileSize) {
            commonFailureBlock(fileName, fileSize, filePath, [NSError sendFileErrorOfflineFileTooBig]);
            return;
        }
    }

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTMessageAbstract *message = [realmManager addMessageWithFileNumber:UINT32_MAX
                                                                fileType:OCTMessageFileTypeLoading
                                                                fileSize:fileSize
                                                                fileName:fileName
                                                                filePath:filePath
                                                                 fileUTI:[self fileUTIFromFileName:fileName]
                                                                    chat:chat
                                                                  sender:nil
                                                            dateInterval:0
                                                               isOffline:isToBot
                                                               messageId:messageId
                                                                  opened:YES];
    
    NSDictionary *userInfo = [self fileOperationUserInfoWithMessage:message chat:chat friendPK:friend.publicKey];
    OCTFilePathInput *input = [[OCTFilePathInput alloc] initWithFilePath:filePath];

    OCTFileUploadOperation *operation = [[OCTFileUploadOperation alloc] initWithTox:[self.dataSource managerGetTox]
                                                                          fileInput:input
                                                                       friendNumber:friendID
                                                                         fileNumber:-1
                                                                           fileSize:fileSize
                                                                           userInfo:userInfo
                                                                      progressBlock:[self fileProgressBlockWithMessage:message]
                                                                     etaUpdateBlock:[self fileEtaUpdateBlockWithMessage:message]
                                                                       successBlock:[self fileSuccessBlockWithMessage:message]
                                                                       failureBlock:[self fileFailureBlockWithMessage:message
                                                                                                     userFailureBlock:failureBlock]];

    [self addOperation:operation];
}

- (void)acceptFileTransfer:(OCTMessageAbstract *)message
              failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock
{
    if (! message.senderUniqueIdentifier) {
        OCTLogError(@"specified wrong message: no sender. %@", message);
        if (failureBlock) {
            failureBlock([NSError acceptFileErrorWrongMessage:message]);
        }
        return;
    }

    if (! message.messageFile) {
        OCTLogError(@"specified wrong message: no messageFile. %@", message);
        if (failureBlock) {
            failureBlock([NSError acceptFileErrorWrongMessage:message]);
        }
        return;
    }

    NSString *uniqueName = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:message.messageFile.fileName.pathExtension];
    OCTFilePathOutput *output = [[OCTFilePathOutput alloc] initWithTempFolder:[self downloadsTempDirectory]
                                                                 resultFolder:[self downloadsDirectory]
                                                                     fileName:uniqueName];
    
    OCTRealmManager *realmManager = self.dataSource.managerGetRealmManager;
    OCTChat *chat = [realmManager objectWithUniqueIdentifier:message.chatUniqueIdentifier class:[OCTChat class]];
    NSDictionary *userInfo = [self fileOperationUserInfoWithMessage:message chat:chat friendPK:nil];
    
    OCTToxFriendNumber friendNumber;
    if (message.messageFile.isOffline) {
        OCTFriend *bot = chat.isGroup ? [self groupBot] : [self offlineBot];
        if (bot.isConnected == NO) {
            if (failureBlock) {
                failureBlock([NSError sendFileErrorFriendNotConnected]);
            }
            return;
        }
        friendNumber = bot.friendNumber;
    } else {
        OCTFriend *friend = [[self.dataSource managerGetRealmManager] objectWithUniqueIdentifier:message.senderUniqueIdentifier
                                                                                           class:[OCTFriend class]];
        friendNumber = friend.friendNumber;
        OCTLogDebug(@"acceptFileTransfer：%@, uniqueIdentifier: %@, filenumber: %d", friend.nickname, friend.uniqueIdentifier, message.messageFile.internalFileNumber);
        
        if (message.messageFile.fileType != OCTMessageFileTypeWaitingConfirmation) {
            OCTLogError(@"specified wrong message: wrong file type, should be WaitingConfirmation. %@", message);
            if (failureBlock) {
                failureBlock([NSError acceptFileErrorWrongMessage:message]);
            }
            return;
        }
    }
    
    OCTFileDownloadOperation *operation = [[OCTFileDownloadOperation alloc]
                                           initWithTox:self.dataSource.managerGetTox
                                           fileOutput:output
                                           friendNumber:friendNumber
                                           fileNumber:message.messageFile.internalFileNumber
                                           fileSize:message.messageFile.fileSize
                                           userInfo:userInfo
                                           messageId:message.messageFile.messageId
                                           progressBlock:[self fileProgressBlockWithMessage:message]
                                           etaUpdateBlock:[self fileEtaUpdateBlockWithMessage:message]
                                           successBlock:[self fileSuccessBlockWithMessage:message]
                                           failureBlock:[self fileFailureBlockWithMessage:message
                                                                         userFailureBlock:failureBlock]
                                           sendPullBlock:[self fileSendPullBlockWithMessage:message]];
    
    [self addOperation:operation];
    
    [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
        file.fileType = OCTMessageFileTypeLoading;
        [file internalSetFilePath:output.resultFilePath];
    }];
}

- (BOOL)cancelFileTransfer:(OCTMessageAbstract *)message error:(NSError **)error
{
    if (! message.messageFile) {
        OCTLogWarn(@"specified wrong message: no messageFile. %@", message);
        if (error) {
            *error = [NSError fileTransferErrorWrongMessage:message];
        }
        return NO;
    }

    OCTFriend *friend = [self friendForMessage:message];
    OCTToxFriendNumber friendNumber = friend.friendNumber;
    
    [self.dataSource.managerGetTox fileSendControlForFileNumber:message.messageFile.internalFileNumber
                                                   friendNumber:friendNumber
                                                        control:OCTToxFileControlCancel
                                                          error:nil];

    OCTFileBaseOperation *operation = [self operationWithFileNumber:message.messageFile.internalFileNumber
                                                       friendNumber:friendNumber];
    [operation cancel];

    [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
        file.fileType = OCTMessageFileTypeCanceled;
        file.internalFileNumber = -1;
    }];

    return YES;
}

- (void)retrySendingFile:(nonnull OCTMessageAbstract *)message
            failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock
{
    NSParameterAssert(message);
    if (! message.messageFile) {
        OCTLogError(@"specified wrong message: no messageFile. %@", message);
        if (failureBlock) {
            failureBlock([NSError acceptFileErrorWrongMessage:message]);
        }
        return;
    }
    
    for (OCTFileUploadOperation *operation in self.uploadQueue) {
        NSString *identifier = operation.userInfo[kMessageIdentifierKey];
        if ([identifier isEqualToString:message.uniqueIdentifier]) {
            failureBlock([NSError sendFileErrorInternalError]);
            return;
        }
    }
    
    NSString *filePath = message.messageFile.filePath;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    
    if (! attributes) {
        OCTLogWarn(@"cannot read file %@", filePath);
        failureBlock([NSError sendFileErrorCannotReadFile]);
        return;
    }
    
    OCTToxFileSize fileSize = [attributes[NSFileSize] longLongValue];
    
    OCTChat *chat = [[self.dataSource managerGetRealmManager] objectWithUniqueIdentifier:message.chatUniqueIdentifier class:[OCTChat class]];
    
    OCTFriend *friend;
    if (chat.isGroup) {
        friend = [self groupBot];
        if (message.messageFile.isOffline == NO) {
            [self updateMessageFile:message withBlock:^(OCTMessageFile *theFile) {
                theFile.isOffline = YES;
            }];
        }
    } else {
        OCTFriend *toFriend = chat.friends.firstObject;
        if (toFriend.isConnected) {
            friend = toFriend;
            
            if (message.messageFile.isOffline) {
                [self updateMessageFile:message withBlock:^(OCTMessageFile *theFile) {
                    theFile.isOffline = NO;
                }];
            }
        } else {
            friend = [self offlineBot];
            if (message.messageFile.isOffline == NO) {
                [self updateMessageFile:message withBlock:^(OCTMessageFile *theFile) {
                    theFile.isOffline = YES;
                }];
            }
        }
    }
    
    if (friend.isConnected == NO) {
        if (failureBlock) {
            failureBlock([NSError sendFileErrorFriendNotConnected]);
        }
        return;
    }
    
    [self updateMessageFile:message withBlock:^(OCTMessageFile *theFile) {
        theFile.fileType = OCTMessageFileTypeLoading;
    }];
    
    NSDictionary *userInfo = [self fileOperationUserInfoWithMessage:message chat:chat friendPK:friend.publicKey];
    OCTFilePathInput *input = [[OCTFilePathInput alloc] initWithFilePath:filePath];
    
    OCTFileUploadOperation *operation = [[OCTFileUploadOperation alloc] initWithTox:[self.dataSource managerGetTox]
                                                                          fileInput:input
                                                                       friendNumber:friend.friendNumber
                                                                         fileNumber:-1
                                                                           fileSize:fileSize
                                                                           userInfo:userInfo
                                                                      progressBlock:[self fileProgressBlockWithMessage:message]
                                                                     etaUpdateBlock:[self fileEtaUpdateBlockWithMessage:message]
                                                                       successBlock:[self fileSuccessBlockWithMessage:message]
                                                                       failureBlock:[self fileFailureBlockWithMessage:message
                                                                                                     userFailureBlock:failureBlock]];
    
    [self addOperation:operation];
}

- (BOOL)pauseFileTransfer:(BOOL)pause message:(nonnull OCTMessageAbstract *)message error:(NSError **)error
{
    if (! message.messageFile) {
        OCTLogWarn(@"specified wrong message: no messageFile. %@", message);
        if (error) {
            *error = [NSError fileTransferErrorWrongMessage:message];
        }
        return NO;
    }

    OCTToxFileControl control;
    OCTMessageFileType type;
    OCTMessageFilePausedBy pausedBy = message.messageFile.pausedBy;

    if (pause) {
        BOOL pausedByFriend = message.messageFile.pausedBy & OCTMessageFilePausedByFriend;

        if ((message.messageFile.fileType != OCTMessageFileTypeLoading) && ! pausedByFriend) {
            OCTLogWarn(@"message in wrong state %ld", (long)message.messageFile.fileType);
            return YES;
        }

        control = OCTToxFileControlPause;
        type = OCTMessageFileTypePaused;
        pausedBy |= OCTMessageFilePausedByUser;
    }
    else {
        BOOL pausedByUser = message.messageFile.pausedBy & OCTMessageFilePausedByUser;
        if ((message.messageFile.fileType != OCTMessageFileTypePaused) && ! pausedByUser) {
            OCTLogWarn(@"message in wrong state %ld", (long)message.messageFile.fileType);
            return YES;
        }

        control = OCTToxFileControlResume;
        pausedBy &= ~OCTMessageFilePausedByUser;

        type = (pausedBy == OCTMessageFilePausedByNone) ? OCTMessageFileTypeLoading : OCTMessageFileTypePaused;
    }
    
    OCTFriend *friend = [self friendForMessage:message];
    OCTToxFriendNumber friendNumber = friend.friendNumber;

    [self.dataSource.managerGetTox fileSendControlForFileNumber:message.messageFile.internalFileNumber
                                                   friendNumber:friendNumber
                                                        control:control
                                                          error:nil];

    [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
        file.fileType = type;
        file.pausedBy = pausedBy;
    }];

    return YES;
}

- (BOOL)addProgressSubscriber:(nonnull id<OCTSubmanagerFilesProgressSubscriber>)subscriber
              forFileTransfer:(nonnull OCTMessageAbstract *)message
                        error:(NSError **)error
{
    if (! message.messageFile) {
        if (error) {
            *error = [NSError fileTransferErrorWrongMessage:message];
        }
        return NO;
    }

    OCTFriend *friend = [self friendForMessage:message];
    OCTToxFriendNumber friendNumber = friend.friendNumber;

    OCTFileBaseOperation *operation;
    if (message.messageFile.isOffline && !message.isOutgoing) {
        operation = [self operationWithFileMessageId:message.messageFile.messageId];
    } else {
        operation = [self operationWithFileNumber:message.messageFile.internalFileNumber
                                                      friendNumber:friendNumber];
    }
    if (! operation) {
        return YES;
    }

    NSString *identifier = operation.userInfo[kMessageIdentifierKey];
    if (! [identifier isEqualToString:message.uniqueIdentifier]) {
        return YES;
    }

    [subscriber submanagerFilesOnProgressUpdate:operation.progress message:message];
    [subscriber submanagerFilesOnEtaUpdate:operation.eta bytesPerSecond:operation.bytesPerSecond message:message];

    NSHashTable *progressSubscribers = operation.userInfo[kProgressSubscribersKey];
    [progressSubscribers addObject:subscriber];

    return YES;
}

- (BOOL)removeProgressSubscriber:(nonnull id<OCTSubmanagerFilesProgressSubscriber>)subscriber
                 forFileTransfer:(nonnull OCTMessageAbstract *)message
                           error:(NSError **)error
{
    if (! message.messageFile) {
        if (error) {
            *error = [NSError fileTransferErrorWrongMessage:message];
        }
        return NO;
    }

    OCTFriend *friend = [self friendForMessage:message];
    OCTToxFriendNumber friendNumber = friend.friendNumber;

    OCTFileBaseOperation *operation = [self operationWithFileNumber:message.messageFile.internalFileNumber
                                                       friendNumber:friendNumber];

    if (! operation) {
        return YES;
    }

    NSString *identifier = operation.userInfo[kMessageIdentifierKey];
    if (! [identifier isEqualToString:message.uniqueIdentifier]) {
        return YES;
    }

    NSHashTable *progressSubscribers = operation.userInfo[kProgressSubscribersKey];
    [progressSubscribers removeObject:subscriber];

    return YES;
}

- (void)removeAllFileMessages
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"messageFile != nil"];
    OCTRealmManager *realmManager = self.dataSource.managerGetRealmManager;
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    NSMutableArray *messages = @[].mutableCopy;
    for (int i = 0; i < results.count; i++) {
        OCTMessageAbstract *msg = results[i];
        [messages addObject:msg];
    }
    [realmManager removeMessages:messages withoutNotifying:nil];
}

#pragma mark -  OCTToxDelegate

- (void)     tox:(OCTTox *)tox fileReceiveControl:(OCTToxFileControl)control
    friendNumber:(OCTToxFriendNumber)friendNumber
      fileNumber:(OCTToxFileNumber)fileNumber
{
    OCTFileBaseOperation *operation = [self operationWithFileNumber:fileNumber
                                                       friendNumber:friendNumber];

    if (operation == nil) {
        OCTLogError(@"operation not found with fileNumber %d friendNumber %d", fileNumber, friendNumber);
    }
    
    NSString *identifier = operation.userInfo[kMessageIdentifierKey];
    OCTMessageAbstract *message;

    if (identifier) {
        message = [self.dataSource.managerGetRealmManager objectWithUniqueIdentifier:identifier
                                                                               class:[OCTMessageAbstract class]];
    }

    switch (control) {
        case OCTToxFileControlResume: {
            [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
                file.pausedBy &= ~OCTMessageFilePausedByFriend;
                file.fileType = (file.pausedBy == OCTMessageFilePausedByNone) ? OCTMessageFileTypeLoading : OCTMessageFileTypePaused;
            }];
            break;
        }
        case OCTToxFileControlPause: {
            [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
                file.pausedBy |= OCTMessageFilePausedByFriend;
                file.fileType = OCTMessageFileTypePaused;
            }];
            break;
        }
        case OCTToxFileControlCancel: {
            if ([operation isKindOfClass:[OCTFileDownloadOperation class]]) {
                [self.dataSource.managerGetRealmManager removeMessages:@[message] withoutNotifying:nil];
            } else {
                [self updateMessageFile:message withBlock:^(OCTMessageFile *file) {
                    file.fileType = OCTMessageFileTypeCanceled;
                    file.internalFileNumber = -1;
                }];
            }
            [operation cancel];
            break;
        }
    }
}

- (void)     tox:(OCTTox *)tox fileChunkRequestForFileNumber:(OCTToxFileNumber)fileNumber
    friendNumber:(OCTToxFriendNumber)friendNumber
        position:(OCTToxFileSize)position
          length:(size_t)length
{
    OCTFileBaseOperation *operation = [self operationWithFileNumber:fileNumber
                                                       friendNumber:friendNumber];

    if ([operation isKindOfClass:[OCTFileUploadOperation class]]) {
        [(OCTFileUploadOperation *)operation chunkRequestWithPosition:position length:length];
    }
    else {
        OCTLogDebug(@"[fileChunkRequestForFileNumber] operation not found with fileNumber %d friendNumber %d", fileNumber, friendNumber);
        [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
    }
}

- (void)     tox:(OCTTox *)tox fileReceiveForFileNumber:(OCTToxFileNumber)fileNumber
    friendNumber:(OCTToxFriendNumber)friendNumber
            kind:(OCTToxFileKind)kind
        fileSize:(OCTToxFileSize)fileSize
        fileName:(NSData *)fileName
{
    switch (kind) {
        case OCTToxFileKindData: {
            if (friendNumber == [self findFriendBot].friendNumber) {
                [self strangerAvatarFileReceiveForFileNumber:fileNumber
                                                friendNumber:friendNumber
                                                        kind:kind
                                                    fileSize:fileSize
                                                        data:fileName];
                return;
            }
            
            [self dataFileReceiveForFileNumber:fileNumber
                                  friendNumber:friendNumber
                                          kind:kind
                                      fileSize:fileSize
                                      fileName:fileName];
            break;
        }
        case OCTToxFileKindAvatar: {
            NSString *name = [[NSString alloc] initWithData:fileName encoding:NSUTF8StringEncoding];
            [self avatarFileReceiveForFileNumber:fileNumber
                                    friendNumber:friendNumber
                                            kind:kind
                                        fileSize:fileSize
                                        fileName:name];
            break;
        }
    }
}

- (void)     tox:(OCTTox *)tox fileReceiveChunk:(NSData *)chunk
      fileNumber:(OCTToxFileNumber)fileNumber
    friendNumber:(OCTToxFriendNumber)friendNumber
        position:(OCTToxFileSize)position
{
    OCTFileBaseOperation *operation = [self operationWithFileNumber:fileNumber
                                                       friendNumber:friendNumber];

    if ([operation isKindOfClass:[OCTFileDownloadOperation class]]) {
        [(OCTFileDownloadOperation *)operation receiveChunk:chunk position:position];
    }
    else {
        OCTLogDebug(@"[fileReceiveChunk] operation not found with fileNumber %d friendNumber %d", fileNumber, friendNumber);
        [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
    }
}

#pragma mark -  NSNotification

- (void)friendConnectionStatusChangeNotification:(NSNotification *)notification
{
    NSString *publicKey = notification.object;

    OCTFriend *friend = [self.dataSource.managerGetRealmManager friendWithPublicKey:publicKey];
    if (! friend) {
        OCTLogWarn(@"no friend received in notification %@, exiting", notification);
        return;
    }

    [self sendAvatarToFriend:friend];
}

- (void)userAvatarWasUpdatedNotification
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"connectionStatus != %d", OCTToxConnectionStatusNone];
    RLMResults *onlineFriends = [self.dataSource.managerGetRealmManager objectsWithClass:[OCTFriend class] predicate:predicate];

    for (OCTFriend *friend in onlineFriends) {
        [self sendAvatarToFriend:friend];
    }
}

- (void)receivedBotFileMessageNotification:(NSNotification *)notification
{
    OCTToxMessageId messageId;
    NSString *fileName;
    OCTToxFileSize fileSize;
    OCTChat *chat;
    NSString *friendPK;
    OCTObject *sender;
    NSTimeInterval createTime;
    
    OCTRealmManager *realmManager = self.dataSource.managerGetRealmManager;
    if ([notification.object isKindOfClass:[GroupRealMsg class]]) {
        GroupRealMsg *message = notification.object;
        
        messageId = message.msgId;
        fileName = [[NSString alloc] initWithData:message.fileDisplayName encoding:NSUTF8StringEncoding];
        fileSize = message.fileSize;
        createTime = message.createTime / 1000.0;
        
        chat = [realmManager getOrCreateChatWithGroupNumber:message.groupId];
        friendPK = [[NSString alloc] initWithData:message.frPk encoding:NSUTF8StringEncoding];
        
        NSString *nickname = [[NSString alloc] initWithData:message.frName encoding:NSUTF8StringEncoding];
        OCTPeer *peer = [realmManager peerWithPeerPK:friendPK groupNumber:message.groupId];
        if (peer == nil) {
            peer = [OCTPeer new];
            peer.publicKey = friendPK;
            peer.groupNumber = message.groupId;
            peer.nickname = nickname;
            [self.dataSource.managerGetRealmManager addObject:peer];
        } else if ((nickname != nil || ![nickname isEqualToString:@""]) && ![peer.nickname isEqualToString:nickname]) {
            [realmManager updateObject:peer withBlock:^(OCTPeer *thePeer) {
                thePeer.nickname = nickname;
            }];
        }
        
        sender = peer;
    } else if ([notification.object isKindOfClass:[OfflineMessage class]]) {
        OfflineMessage *message = notification.object;
        
        messageId = message.msgId;
        fileName = [[NSString alloc] initWithData:message.fileDisplayName encoding:NSUTF8StringEncoding];
        fileSize = message.fileSize;
        createTime = message.createTime / 1000.0;
        
        friendPK = [[NSString alloc] initWithData:message.frPk encoding:NSUTF8StringEncoding];
        OCTFriend *friend = [realmManager friendWithPublicKey:friendPK];
        chat = [realmManager getOrCreateChatWithFriend:friend];
        sender = friend;
    } else {
        return;
    }
    
    OCTLogInfo(@"👏👏Received Bot File. messageId: %lld, fileName: %@, fileSize: %lld, groupId: %lld", messageId, fileName, fileSize, chat.groupNumber);

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageFile.messageId == %lld",
                                  chat.uniqueIdentifier, messageId];
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    OCTMessageAbstract *fileMessage = results.firstObject;
    if (fileMessage != nil) {
        if (fileMessage.messageFile.fileType == OCTMessageFileTypeReady) {
            return;
        }
        if ([self operationWithFileMessageId:messageId]) {
            OCTLogInfo(@"😏😏😏MessageFile is enqueue. messageId: %lld, fileName: %@, fileSize: %lld, groupId: %lld", messageId, fileName, fileSize, chat.groupNumber);
            return;
        }
        [self updateMessageFile:fileMessage withBlock:^(OCTMessageFile *theFileMessage) {
            theFileMessage.fileType = OCTMessageFileTypeWaitingConfirmation;
        }];
        
        // enqueue
        [self acceptFileTransfer:fileMessage failureBlock:nil];
        return;
    }
    
    if (sender == nil) {
        OCTLogWarn(@"‼️‼️‼️BotMessageFile Sender is nil. %lld", messageId);
        return;
    }
    
    [realmManager addMessageWithFileNumber:UINT32_MAX
                                  fileType:OCTMessageFileTypeWaitingConfirmation
                                  fileSize:fileSize
                                  fileName:fileName
                                  filePath:nil
                                   fileUTI:[self fileUTIFromFileName:fileName]
                                      chat:chat
                                    sender:sender
                              dateInterval:createTime
                                 isOffline:YES
                                 messageId:messageId
                                    opened:NO];
}

#pragma mark -  Private

- (OCTFriend *)groupBot
{
    NSString *botPublicKey = [self.dataSource getGroupMessageBotPublicKey];
    if (botPublicKey == nil) {
        return nil;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    return bot;
}

- (OCTFriend *)offlineBot
{
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        return nil;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    return bot;
}

- (OCTFriend *)findFriendBot
{
    NSString *botPublicKey = [self.dataSource getStrangerMessageBotPublicKey];
    if (botPublicKey == nil) {
        return nil;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    return bot;
}

- (void)scheduleFilesCleanup
{
    @synchronized(self.filesCleanupLock) {
        if (self.filesCleanupInProgress) {
            return;
        }
        self.filesCleanupInProgress = YES;
    }

    OCTLogInfo(@"cleanup: starting files cleanup");

    NSString *uploads = [self uploadsDirectory];
    NSString *downloads = [self downloadsDirectory];

    __weak OCTSubmanagerFilesImpl *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSMutableSet *allFiles = [NSMutableSet new];

        NSError *error;
        NSArray<NSString *> *uploadsContents = [fileManager contentsOfDirectoryAtPath:uploads error:&error];
        if (uploadsContents) {
            for (NSString *file in uploadsContents) {
                [allFiles addObject:[uploads stringByAppendingPathComponent:file]];
            }
        }
        else {
            OCTLogWarn(@"cleanup: cannot read contents of uploads directory %@, error %@", uploads, error);
        }

        NSArray<NSString *> *downloadsContents = [fileManager contentsOfDirectoryAtPath:downloads error:&error];
        if (downloadsContents) {
            for (NSString *file in downloadsContents) {
                [allFiles addObject:[downloads stringByAppendingPathComponent:file]];
            }
        }
        else {
            OCTLogWarn(@"cleanup: cannot read contents of download directory %@, error %@", downloads, error);
        }

        OCTLogInfo(@"cleanup: total number of files %lu", (unsigned long)allFiles.count);
        OCTToxFileSize freedSpace = 0;

        for (NSString *path in allFiles) {
            __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;
            if (! strongSelf) {
                OCTLogWarn(@"cleanup: submanager was killed, quiting");
            }

            __block BOOL exists = NO;

            dispatch_sync(dispatch_get_main_queue(), ^{
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"internalFilePath == %@",
                                          [path stringByAbbreviatingWithTildeInPath]];

                OCTRealmManager *realmManager = strongSelf.dataSource.managerGetRealmManager;
                RLMResults *results = [realmManager objectsWithClass:[OCTMessageFile class] predicate:predicate];

                exists = (results.count > 0);
            });

            if (exists) {
                continue;
            }

            OCTLogInfo(@"cleanup: found unbounded file, removing it. Path %@", path);

            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
            if (! attributes) {
                OCTLogWarn(@"cleanup: cannot read file at path %@, error %@", path, error);
            }

            if ([fileManager removeItemAtPath:path error:&error]) {
                freedSpace += [attributes[NSFileSize] longLongValue];
            }
            else {
                OCTLogWarn(@"cleanup: cannot remove file at path %@, error %@", path, error);
            }
        }

        OCTLogInfo(@"cleanup: done. Freed %lld bytes.", freedSpace);

        __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;
        @synchronized(strongSelf.filesCleanupLock) {
            strongSelf.filesCleanupInProgress = NO;
        }
    });
}

- (OCTFileBaseOperation *)operationWithFileNumber:(OCTToxFileNumber)fileNumber friendNumber:(OCTToxFriendNumber)friendNumber
{
    NSString *operationId = [OCTFileBaseOperation operationIdFromFileNumber:fileNumber friendNumber:friendNumber];
    
    for (OCTFileBaseOperation *operation in self.queue.operations) {
        if ([operation.operationId isEqualToString:operationId]) {
            return operation;
        }
    }
    
    for (OCTFileBaseOperation *operation in self.uploadQueue) {
        if ([operation.operationId isEqualToString:operationId]) {
            return operation;
        }
    }
    
    for (OCTFileBaseOperation *operation in self.downloadQueue) {
        if ([operation.operationId isEqualToString:operationId]) {
            return operation;
        }
    }

    return nil;
}

- (OCTFileDownloadOperation *)operationWithFileMessageId:(OCTToxMessageId)messageId
{
    for (OCTFileDownloadOperation *operation in self.downloadQueue) {
        if (operation.messageId == messageId) {
            return operation;
        }
    }
    
    return nil;
}

- (void)createDirectoryIfNeeded:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDirectory;
    BOOL exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];

    if (exists && ! isDirectory) {
        [fileManager removeItemAtPath:path error:nil];
        exists = NO;
    }

    if (! exists) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSString *)downloadsDirectory
{
    id<OCTFileStorageProtocol> fileStorage = self.dataSource.managerGetFileStorage;

    NSString *path = fileStorage.pathForDownloadedFilesDirectory;
    [self createDirectoryIfNeeded:path];

    return path;
}

- (NSString *)uploadsDirectory
{
    id<OCTFileStorageProtocol> fileStorage = self.dataSource.managerGetFileStorage;

    NSString *path = fileStorage.pathForUploadedFilesDirectory;
    [self createDirectoryIfNeeded:path];

    return path;
}

- (NSString *)downloadsTempDirectory
{
    id<OCTFileStorageProtocol> fileStorage = self.dataSource.managerGetFileStorage;

    NSString *path = [fileStorage.pathForTemporaryFilesDirectory stringByAppendingPathComponent:kDownloadsTempDirectory];
    [self createDirectoryIfNeeded:path];

    return path;
}

- (NSString *)avatarsDirectory
{
    id<OCTFileStorageProtocol> fileStorage = self.dataSource.managerGetFileStorage;
    
    NSString *path = fileStorage.pathForAvatarsDirectory;
    [self createDirectoryIfNeeded:path];
    
    return path;
}

- (NSString *)fileUTIFromFileName:(NSString *)fileName
{
    NSString *extension = [fileName pathExtension];

    if (! extension) {
        return nil;
    }

    return (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(
        kUTTagClassFilenameExtension,
        (__bridge CFStringRef)extension,
        NULL);
}

- (void)updateMessageFile:(OCTMessageAbstract *)message withBlock:(void (^)(OCTMessageFile *))block
{
    if (! message) {
        return;
    }

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];

    [realmManager updateObject:message.messageFile withBlock:block];

    // Workaround to force Realm to update OCTMessageAbstract when OCTMessageFile was updated.
    [realmManager updateObject:message withBlock:^(OCTMessageAbstract *message) {
        message.dateInterval = message.dateInterval;
    }];
}

- (OCTFileBaseOperationProgressBlock)fileProgressBlockWithMessage:(OCTMessageAbstract *)message
{
    return ^(OCTFileBaseOperation *__nonnull operation) {
        if (message.isInvalidated) {
            return;
        }
        NSHashTable *progressSubscribers = operation.userInfo[kProgressSubscribersKey];
        
        for (id<OCTSubmanagerFilesProgressSubscriber> subscriber in progressSubscribers) {
            [subscriber submanagerFilesOnProgressUpdate:operation.progress message:message];
        }
    };
}

- (OCTFileBaseOperationProgressBlock)fileEtaUpdateBlockWithMessage:(OCTMessageAbstract *)message
{
    return ^(OCTFileBaseOperation *__nonnull operation) {
        if (message.isInvalidated) {
            return;
        }
        NSHashTable *progressSubscribers = operation.userInfo[kProgressSubscribersKey];
        
        for (id<OCTSubmanagerFilesProgressSubscriber> subscriber in progressSubscribers) {
            [subscriber submanagerFilesOnEtaUpdate:operation.eta
                                    bytesPerSecond:operation.bytesPerSecond
                                           message:message];
        }
    };
}

- (OCTFileBaseOperationSuccessBlock)fileSuccessBlockWithMessage:(OCTMessageAbstract *)message
{
    __weak OCTSubmanagerFilesImpl *weakSelf = self;

    return ^(OCTFileBaseOperation *__nonnull operation) {
        if (message.isInvalidated) {
            return;
        }
        __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;
        [strongSelf updateMessageFile:message withBlock:^(OCTMessageFile *file) {
            file.fileType = OCTMessageFileTypeReady;
        }];
    };
}

- (OCTFileBaseOperationFailureBlock)fileFailureBlockWithMessage:(OCTMessageAbstract *)message
                                               userFailureBlock:(void (^)(NSError *))userFailureBlock
{
    __weak OCTSubmanagerFilesImpl *weakSelf = self;

    return ^(OCTFileBaseOperation *__nonnull operation, NSError *__nonnull error) {
        __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;
        if (message.isInvalidated) {
            return;
        }
        [strongSelf updateMessageFile:message withBlock:^(OCTMessageFile *file) {
            file.fileType = OCTMessageFileTypeCanceled;
            
            if (userFailureBlock) {
                userFailureBlock(error);
            }
        }];
    };
}

- (OCTFileBaseOperationPullBlock)fileSendPullBlockWithMessage:(OCTMessageAbstract *)message
{
    __weak OCTSubmanagerFilesImpl *weakSelf = self;
    
    return ^(OCTFileBaseOperation *__nonnull operation) {
        __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;
        if (message.isInvalidated) {
            return;
        }
        if (message.messageFile.isOffline) {
            NSNumber *isGroup = operation.userInfo[kMessageIsGroupKey];
            if (isGroup) {
                NSNumber *groupNumber = operation.userInfo[kMessageGroupNumberKey];
                [strongSelf sendReceiveGroupFileMessage:message groupNumber:groupNumber.integerValue];
            } else {
                [strongSelf sendReceiveOfflineFileMessage:message];
            }
        } else {
            [(OCTFileDownloadOperation *)operation run];
        }
    };
}

- (NSDictionary *)fileOperationUserInfoWithMessage:(OCTMessageAbstract *)message chat:(OCTChat *)chat friendPK:(NSString *)friendPK
{
    NSMutableDictionary *userInfo = @{
                                      kProgressSubscribersKey : [NSHashTable weakObjectsHashTable],
                                      kMessageIdentifierKey : message.uniqueIdentifier,
                                      }.mutableCopy;
    
    if (chat.isGroup) {
        userInfo[kMessageGroupNumberKey] = @(chat.groupNumber);
        userInfo[kMessageIsGroupKey] = @(chat.isGroup);
    }
    
    if (friendPK) {
        userInfo[kMessageToFriendPKKey] = friendPK;
    }
    
    return userInfo;
}

- (void)sendAvatarToFriend:(OCTFriend *)friend
{
    NSParameterAssert(friend);

    NSData *avatar = self.dataSource.managerGetRealmManager.settingsStorage.userAvatarData;

    if (! avatar) {
        [[self.dataSource managerGetTox] fileSendWithFriendNumber:friend.friendNumber
                                                             kind:OCTToxFileKindAvatar
                                                         fileSize:0
                                                           fileId:nil
                                                         fileName:nil
                                                            error:nil];
        return;
    }

    OCTToxFileSize fileSize = avatar.length;
    NSData *hash = [self.dataSource.managerGetTox hashData:avatar];

    NSError *error;
    OCTToxFileNumber fileNumber = [[self.dataSource managerGetTox] fileSendWithFriendNumber:friend.friendNumber
                                                                                       kind:OCTToxFileKindAvatar
                                                                                   fileSize:fileSize
                                                                                     fileId:hash
                                                                                   fileName:nil
                                                                                      error:&error];

    if (fileNumber == kOCTToxFileNumberFailure) {
        OCTLogWarn(@"cannot send file %@", error);
        return;
    }

    OCTFileDataInput *input = [[OCTFileDataInput alloc] initWithData:avatar];

    OCTFileUploadOperation *operation = [[OCTFileUploadOperation alloc] initWithTox:[self.dataSource managerGetTox]
                                                                          fileInput:input
                                                                       friendNumber:friend.friendNumber
                                                                         fileNumber:fileNumber
                                                                           fileSize:fileSize
                                                                           userInfo:nil
                                                                      progressBlock:nil
                                                                     etaUpdateBlock:nil
                                                                       successBlock:nil
                                                                       failureBlock:nil];

    [self.queue addOperation:operation];
}

- (void)dataFileReceiveForFileNumber:(OCTToxFileNumber)fileNumber
                        friendNumber:(OCTToxFriendNumber)friendNumber
                                kind:(OCTToxFileKind)kind
                            fileSize:(OCTToxFileSize)fileSize
                            fileName:(NSData *)fileName
{
    if (fileSize == 0) {
        OCTLogWarn(@"Received file with size 0, ignoring it.");
        [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
        return;
    }

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    
    OCTLogInfo(@"File receive. friend id: %@, friend number: %d, file number: %d", friend.uniqueIdentifier, friendNumber, fileNumber);

    if (friend == nil) {
        [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
        return;
    }
    
    BOOL isGroup = [friend.publicKey isEqualToString:[self.dataSource getGroupMessageBotPublicKey]];
    BOOL isOffline = [friend.publicKey isEqualToString:[self.dataSource getOfflineMessageBotPublicKey]];
    if (isGroup || isOffline) {
        NSError *error;
        FileTransfer *model = [FileTransfer parseFromData:fileName error:&error];
        if (error) {
            [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
            return;
        }
        
        OCTChat *chat;
        if (isGroup) {
            chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
        } else {
            NSString *friendPK = [[NSString alloc] initWithData:model.frPk encoding:NSUTF8StringEncoding];
            OCTFriend *friend = [realmManager friendWithPublicKey:friendPK];
            chat = [realmManager getOrCreateChatWithFriend:friend];
        }
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageFile.messageId == %lld",
                                  chat.uniqueIdentifier, model.msgId];
        RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
        OCTMessageAbstract *fileMessage = results.firstObject;
        if (fileMessage != nil) {
            [self updateMessageFile:fileMessage withBlock:^(OCTMessageFile *file) {
                file.internalFileNumber = fileNumber;
                file.fileSize = fileSize;
                file.expired = model.code == 1;
            }];
            
            OCTFileDownloadOperation *operation = [self operationWithFileMessageId:fileMessage.messageFile.messageId];
            operation.fileNumber = fileNumber;
            [operation run];
        } else {
            [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
        }
        return;
    }
    
    OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
    NSString *realFileName = [[NSString alloc] initWithData:fileName encoding:NSUTF8StringEncoding];
    [realmManager addMessageWithFileNumber:fileNumber
                                  fileType:OCTMessageFileTypeWaitingConfirmation
                                  fileSize:fileSize
                                  fileName:realFileName
                                  filePath:nil
                                   fileUTI:[self fileUTIFromFileName:realFileName]
                                      chat:chat
                                    sender:friend
                              dateInterval:0
                                 isOffline:NO
                                 messageId:[self.dataSource.managerGetTox generateMessageId]
                                    opened:NO];
}

- (void)avatarFileReceiveForFileNumber:(OCTToxFileNumber)fileNumber
                          friendNumber:(OCTToxFriendNumber)friendNumber
                                  kind:(OCTToxFileKind)kind
                              fileSize:(OCTToxFileSize)fileSize
                              fileName:(NSString *)fileName
{
    void (^cancelBlock)(void) = ^() {
        [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
    };

    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [[self.dataSource managerGetRealmManager] friendWithPublicKey:publicKey];

    if (fileSize == 0) {
        if (friend.avatarData) {
            [[self.dataSource managerGetRealmManager] updateObject:friend withBlock:^(OCTFriend *theFriend) {
                theFriend.avatarData = nil;
            }];
        }

        cancelBlock();
        return;
    }

    if (fileSize > kOCTManagerMaxAvatarSize) {
        OCTLogWarn(@"received avatar is too big, ignoring it, size %lld", fileSize);
        cancelBlock();
        return;
    }

    NSData *hash = [self.dataSource.managerGetTox hashData:friend.avatarData];
    NSData *remoteHash = [self.dataSource.managerGetTox fileGetFileIdForFileNumber:fileNumber
                                                                      friendNumber:friendNumber
                                                                             error:nil];

    if (remoteHash && [hash isEqual:remoteHash]) {
        OCTLogInfo(@"received same avatar, ignoring it");
        cancelBlock();
        return;
    }

    OCTFileDataOutput *output = [OCTFileDataOutput new];
    __weak OCTSubmanagerFilesImpl *weakSelf = self;

    OCTFileDownloadOperation *operation = [[OCTFileDownloadOperation alloc] initWithTox:self.dataSource.managerGetTox
                                                                             fileOutput:output
                                                                           friendNumber:friendNumber
                                                                             fileNumber:fileNumber
                                                                               fileSize:fileSize
                                                                               userInfo:nil
                                                                              messageId:-1
                                                                          progressBlock:nil
                                                                         etaUpdateBlock:nil
                                                                           successBlock:^(OCTFileBaseOperation *__nonnull operation) {
        __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;

        NSString *publicKey = [[strongSelf.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
        OCTFriend *friend = [[strongSelf.dataSource managerGetRealmManager] friendWithPublicKey:publicKey];

        [[strongSelf.dataSource managerGetRealmManager] updateObject:friend withBlock:^(OCTFriend *theFriend) {
            theFriend.avatarData = output.resultData;
        }];
                                                                               
        // Write to /avatars
        NSString *fileName = [publicKey stringByAppendingPathExtension:@"png"];
        NSString *path = [[strongSelf avatarsDirectory] stringByAppendingPathComponent:fileName];
        [output.resultData writeToFile:path atomically:NO];
    } failureBlock:nil sendPullBlock:nil];

    [self.queue addOperation:operation];
}

- (void)strangerAvatarFileReceiveForFileNumber:(OCTToxFileNumber)fileNumber
                                  friendNumber:(OCTToxFriendNumber)friendNumber
                                          kind:(OCTToxFileKind)kind
                                      fileSize:(OCTToxFileSize)fileSize
                                      data:(NSData *)data
{
    void (^cancelBlock)(void) = ^() {
        [self.dataSource.managerGetTox fileSendControlForFileNumber:fileNumber friendNumber:friendNumber control:OCTToxFileControlCancel error:nil];
    };
    
    if (fileSize == 0) {
        cancelBlock();
        return;
    }
    
    if (fileSize > kOCTManagerMaxAvatarSize) {
        OCTLogWarn(@"received avatar is too big, ignoring it, size %lld", fileSize);
        cancelBlock();
        return;
    }
    NSError *error;
    FileTransfer *model = [FileTransfer parseFromData:data error:&error];
    if (error) {
        cancelBlock();
        return;
    }
    
    NSString *publicKey = [[NSString alloc] initWithData:model.frPk encoding:NSUTF8StringEncoding];
    OCTFileDataOutput *output = [OCTFileDataOutput new];
    __weak OCTSubmanagerFilesImpl *weakSelf = self;
    
    OCTFileDownloadOperation *operation = [[OCTFileDownloadOperation alloc] initWithTox:self.dataSource.managerGetTox
                                                                             fileOutput:output
                                                                           friendNumber:friendNumber
                                                                             fileNumber:fileNumber
                                                                               fileSize:fileSize
                                                                               userInfo:nil
                                                                              messageId:-1
                                                                          progressBlock:nil
                                                                         etaUpdateBlock:nil
                                                                           successBlock:^(OCTFileBaseOperation *__nonnull operation) {
                                                                               __strong OCTSubmanagerFilesImpl *strongSelf = weakSelf;
                                                                               
                                                                               // Write to /avatars
                                                                               NSString *fileName = [publicKey stringByAppendingPathExtension:@"png"];
                                                                               NSString *path = [[strongSelf avatarsDirectory] stringByAppendingPathComponent:fileName];
                                                                               [output.resultData writeToFile:path atomically:NO];
                                                                               
                                                                               NSDictionary *userInfo = @{@"path": path, @"publicKey": publicKey};
                                                                               [[NSNotificationCenter defaultCenter] postNotificationName:kOCTStrangerAvatarReceivedNotification object:nil userInfo:userInfo];
                                                                           } failureBlock:nil sendPullBlock:nil];
    
    [self.queue addOperation:operation];
}

- (OCTFriend *)friendForMessage:(OCTMessageAbstract *)message
{
    OCTChat *chat = [[self.dataSource managerGetRealmManager] objectWithUniqueIdentifier:message.chatUniqueIdentifier
                                                                                   class:[OCTChat class]];
    
    if (message.messageFile.isOffline) {
        return chat.isGroup ? [self groupBot] : [self offlineBot];
    }
    return [chat.friends firstObject];
}

- (void)sendReceiveGroupFileMessage:(OCTMessageAbstract *)message groupNumber:(NSInteger)groupNumber
{
    OCTToxMessageId messageId = message.messageFile.messageId;
    
    GroupFilePullReq *pull = [GroupFilePullReq new];
    pull.msgId = messageId;
    pull.groupId = groupNumber;
    
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:self.dataSource.managerGetTox
                                                                                            cmd:OCTToxGroupCmdFilePull
                                                                                botFriendNumber:[self groupBot].friendNumber
                                                                                      messageId:messageId
                                                                                        message:[pull data]
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    [_queue addOperation:operation];
}

- (void)sendReceiveOfflineFileMessage:(OCTMessageAbstract *)message
{
    OfflineFilePullReq *pull = [OfflineFilePullReq new];
    pull.msgId = message.messageFile.messageId;
    
    OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:self.dataSource.managerGetTox
                                                                                                       cmd:OCTToxMessageOfflineCmdFilePull
                                                                                           botFriendNumber:[self offlineBot].friendNumber
                                                                                                   message:[pull data]];
    [_queue addOperation:operation];
}

@end
