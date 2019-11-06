// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Realm/Realm.h>

#import "OCTRealmManager.h"
#import "OCTFriend.h"
#import "OCTFriendRequest.h"
#import "OCTChat.h"
#import "OCTCall.h"
#import "OCTMessageAbstract.h"
#import "OCTMessageText.h"
#import "OCTMessageFile.h"
#import "OCTMessageCall.h"
#import "OCTSettingsStorageObject.h"
#import "OCTLogging.h"

const uint64_t kCurrentSchemeVersion = 15;
static NSString *kSettingsStorageObjectPrimaryKey = @"kSettingsStorageObjectPrimaryKey";

@interface OCTRealmManager ()

@property (strong, nonatomic) dispatch_queue_t queue;
@property (strong, nonatomic) RLMRealm *realm;

@property (strong, nonatomic) NSURL *fileURL;
@property (strong, nonatomic) NSData *encryptionKey;

@end

@implementation OCTRealmManager
@synthesize settingsStorage = _settingsStorage;

#pragma mark -  Class methods

+ (BOOL)migrateToEncryptedDatabase:(NSString *)databasePath
                     encryptionKey:(NSData *)encryptionKey
                             error:(NSError **)error
{
    NSString *tempPath = [databasePath stringByAppendingPathExtension:@"tmp"];

    @autoreleasepool {
        RLMRealm *old = [OCTRealmManager createRealmWithFileURL:[NSURL fileURLWithPath:databasePath]
                                                  encryptionKey:nil
                                                          error:error];

        if (! old) {
            return NO;
        }

        if (! [old writeCopyToURL:[NSURL fileURLWithPath:tempPath] encryptionKey:encryptionKey error:error]) {
            return NO;
        }
    }

    if (! [[NSFileManager defaultManager] removeItemAtPath:databasePath error:error]) {
        return NO;
    }

    if (! [[NSFileManager defaultManager] moveItemAtPath:tempPath toPath:databasePath error:error]) {
        return NO;
    }

    return YES;
}

#pragma mark -  Lifecycle

- (instancetype)initWithDatabaseFileURL:(NSURL *)fileURL encryptionKey:(NSData *)encryptionKey
{
    NSParameterAssert(fileURL);

    self = [super init];

    if (! self) {
        return nil;
    }

    OCTLogInfo(@"init with fileURL %@", fileURL);

    _queue = dispatch_queue_create("OCTRealmManager queue", NULL);
    
    _fileURL = fileURL;
    _encryptionKey = encryptionKey.copy;

    __weak OCTRealmManager *weakSelf = self;
    dispatch_sync(_queue, ^{
        __strong OCTRealmManager *strongSelf = weakSelf;

        // TODO handle error
        self->_realm = [OCTRealmManager createRealmWithFileURL:fileURL encryptionKey:encryptionKey error:nil];
        [strongSelf createSettingsStorage];
    });

    [self convertAllCallsToMessages];

    return self;
}

#pragma mark -  Public

- (RLMRealm *)database
{
    RLMRealm *realm = [OCTRealmManager createRealmWithFileURL:_fileURL encryptionKey:_encryptionKey error:nil];
    [realm refresh];
    return realm;
}

- (void)refresh
{
    [self.realm refresh];
}

#pragma mark -  Basic methods

- (RLMResults *)objectsWithClass:(Class)class predicate:(NSPredicate *)predicate db:(RLMRealm *)db
{
    NSParameterAssert(class);
    
    RLMResults *results = [class objectsInRealm:db withPredicate:predicate];
    return results;
}

- (id)objectWithUniqueIdentifier:(NSString *)uniqueIdentifier class:(Class)class
{
    NSParameterAssert(uniqueIdentifier);
    NSParameterAssert(class);

    __block OCTObject *object = nil;

    dispatch_sync(self.queue, ^{
        object = [class objectInRealm:self.realm forPrimaryKey:uniqueIdentifier];
    });

    return object;
}

- (RLMResults *)objectsWithClass:(Class)class predicate:(NSPredicate *)predicate
{
    NSParameterAssert(class);

    __block RLMResults *results;

    dispatch_sync(self.queue, ^{
        results = [class objectsInRealm:self.realm withPredicate:predicate];
    });

    return results;
}

- (void)updateObject:(OCTObject *)object withBlock:(void (^)(id theObject))updateBlock
{
    NSParameterAssert(object);
    NSParameterAssert(updateBlock);

    OCTLogInfo(@"updateObject %@", object);

    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];

        updateBlock(object);

        [self.realm commitWriteTransaction];
    });
}

- (void)updateObject:(OCTObject *)object db:(RLMRealm *)db withBlock:(void (^)(id theObject))updateBlock
{
    [db beginWriteTransaction];
    
    updateBlock(object);
    
    [db commitWriteTransaction];
}

- (void)updateObject:(OCTObject *)object withBlock:(void (^)(id theObject))updateBlock  withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    NSParameterAssert(object);
    NSParameterAssert(updateBlock);
    
    OCTLogInfo(@"updateObject %@", object);
    
    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];
        
        updateBlock(object);
        
        [self.realm commitWriteTransactionWithoutNotifying:tokens error:nil];
    });
}

- (void)updateObjectsWithClass:(Class)class
                     predicate:(NSPredicate *)predicate
                   updateBlock:(void (^)(id theObject))updateBlock
{
    NSParameterAssert(class);
    NSParameterAssert(updateBlock);

    OCTLogInfo(@"updating objects of class %@ with predicate %@", NSStringFromClass(class), predicate);

    dispatch_sync(self.queue, ^{
        RLMResults *results = [class objectsInRealm:self.realm withPredicate:predicate];

        [self.realm beginWriteTransaction];
        for (id object in results) {
            updateBlock(object);
        }
        [self.realm commitWriteTransaction];
    });
}

- (void)updateObjectsWithClass:(Class)class
                     predicate:(NSPredicate *)predicate
                            db:(RLMRealm *)db
                   updateBlock:(void (^)(id theObject))updateBlock
{
    NSParameterAssert(class);
    NSParameterAssert(updateBlock);
    
    OCTLogInfo(@"updating objects of class %@ with predicate %@", NSStringFromClass(class), predicate);
    
    RLMResults *results = [class objectsInRealm:db withPredicate:predicate];
    
    [db beginWriteTransaction];
    for (id object in results) {
        updateBlock(object);
    }
    [db commitWriteTransaction];
}

- (void)addObjects:(NSArray<OCTObject *> *)objects
{
    NSParameterAssert(objects);
    
    OCTLogInfo(@"add objects %@", objects);
    
    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];
        
        [self.realm addObjects:objects];
        
        [self.realm commitWriteTransaction];
    });
}

- (void)addObject:(OCTObject *)object
{
    NSParameterAssert(object);

    OCTLogInfo(@"add object %@", object);

    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];

        [self.realm addObject:object];

        [self.realm commitWriteTransaction];
    });
}

- (void)addObject:(OCTObject *)object withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    NSParameterAssert(object);
    
    OCTLogInfo(@"add object %@", object);
    
    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];
        
        [self.realm addObject:object];
        
        [self.realm commitWriteTransactionWithoutNotifying:tokens error:nil];
    });
}

- (void)deleteObject:(OCTObject *)object
{
    NSParameterAssert(object);

    OCTLogInfo(@"delete object %@", object);

    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];

        [self.realm deleteObject:object];

        [self.realm commitWriteTransaction];
    });
}

- (void)deleteObject:(OCTObject *)object db:(RLMRealm *)db
{
    NSParameterAssert(object);
    
    OCTLogInfo(@"delete object %@", object);
    
    [db beginWriteTransaction];
    
    [db deleteObject:object];
    
    [db commitWriteTransaction];
}

#pragma mark -  Other methods

+ (RLMRealm *)createRealmWithFileURL:(NSURL *)fileURL encryptionKey:(NSData *)encryptionKey error:(NSError **)error
{
    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.fileURL = fileURL;
    configuration.schemaVersion = kCurrentSchemeVersion;
    configuration.migrationBlock = [self realmMigrationBlock];
    configuration.encryptionKey = encryptionKey;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:error];

    if (! realm && error) {
        OCTLogInfo(@"Cannot create Realm, error %@", *error);
    }

    return realm;
}

- (void)createSettingsStorage
{
    _settingsStorage = [OCTSettingsStorageObject objectInRealm:self.realm
                                                 forPrimaryKey:kSettingsStorageObjectPrimaryKey];

    if (! _settingsStorage) {
        OCTLogInfo(@"no _settingsStorage, creating it");
        _settingsStorage = [OCTSettingsStorageObject new];
        _settingsStorage.uniqueIdentifier = kSettingsStorageObjectPrimaryKey;

        [self.realm beginWriteTransaction];
        [self.realm addObject:_settingsStorage];
        [self.realm commitWriteTransaction];
    }
}

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey
{
//    NSAssert(publicKey, @"Public key should be non-empty.");
    if (publicKey == nil) {
        return nil;
    }
    __block OCTFriend *friend;

    dispatch_sync(self.queue, ^{
        friend = [[OCTFriend objectsInRealm:self.realm where:@"publicKey == %@", publicKey.uppercaseString] firstObject];
    });

    return friend;
}

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey db:(RLMRealm *)db
{
    if (publicKey == nil) {
        return nil;
    }
    OCTFriend *friend = [[OCTFriend objectsInRealm:db where:@"publicKey == %@", publicKey.uppercaseString] firstObject];
    return friend;
}

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey friendState:(NSInteger)friendState
{
    //    NSAssert(publicKey, @"Public key should be non-empty.");
    if (publicKey == nil) {
        return nil;
    }
    __block OCTFriend *friend;
    
    dispatch_sync(self.queue, ^{
        friend = [[OCTFriend objectsInRealm:self.realm where:@"publicKey == %@ AND friendState == %d", publicKey.uppercaseString, friendState] firstObject];
    });
    
    return friend;
}

- (OCTPeer *)peerWithPeerPK:(NSString *)publicKey
{
    __block OCTPeer *peer;
    
    dispatch_sync(self.queue, ^{
        peer = [[OCTPeer objectsInRealm:self.realm where:@"publicKey == %@", [publicKey uppercaseString]] firstObject];
    });
    
    return peer;
}

- (OCTPeer *)peerWithPeerPK:(NSString *)publicKey groupNumber:(NSInteger)groupNumber
{
    __block OCTPeer *peer;
    
    dispatch_sync(self.queue, ^{
        peer = [[OCTPeer objectsInRealm:self.realm where:@"publicKey == %@ AND groupNumber == %ld", [publicKey uppercaseString], groupNumber] firstObject];
    });
    
    return peer;
}

- (void)addPeersWithGroupNumber:(NSInteger)groupNumber peers:(NSArray<OCTPeer *> *)newPeers ownerPublicKey:(NSString *)ownerPublicKey
{
    OCTChat *chat = [self getOrCreateChatWithGroupNumber:groupNumber];
    dispatch_sync(self.queue, ^{
        RLMResults<OCTPeer *> *peers = [OCTPeer objectsInRealm:self.realm where:@"groupNumber == %ld", groupNumber];
        [self.realm beginWriteTransaction];
        [self.realm deleteObjects:peers];
        [self.realm addObjects:newPeers];
        chat.ownerPublicKey = ownerPublicKey;
        [self.realm commitWriteTransaction];
    });
}

- (OCTChat *)getChatWithFriend:(OCTFriend *)friend
{
    __block OCTChat *chat = nil;
    
    dispatch_sync(self.queue, ^{
        // TODO add this (friends.@count == 1) condition. Currentry Realm doesn't support collection queries
        // See https://github.com/realm/realm-cocoa/issues/1490
        chat = [[OCTChat objectsInRealm:self.realm where:@"ANY friends == %@", friend] firstObject];
    });
    
    return chat;
}

- (OCTChat *)getOrCreateChatWithFriend:(OCTFriend *)friend
{
    if (friend == nil) {
        return nil;
    }
    
    __block OCTChat *chat = nil;

    dispatch_sync(self.queue, ^{
        // TODO add this (friends.@count == 1) condition. Currentry Realm doesn't support collection queries
        // See https://github.com/realm/realm-cocoa/issues/1490
        chat = [[OCTChat objectsInRealm:self.realm where:@"ANY friends == %@", friend] firstObject];

        if (chat) {
            return;
        }

        OCTLogInfo(@"creating chat with friend %@", friend);

        chat = [OCTChat new];
        chat.lastActivityDateInterval = [[NSDate date] timeIntervalSince1970];

        [self.realm beginWriteTransaction];

        [self.realm addObject:chat];
        [chat.friends addObject:friend];

        [self addDefaultTipMessageToChat:chat];
        [self.realm commitWriteTransaction];
    });

    return chat;
}

- (void)addDefaultTipMessageToChat:(OCTChat *)chat
{
    // Add default tip message
    OCTMessageText *messageText = [OCTMessageText new];
    messageText.text = chat.isGroup
    ? NSLocalizedString(@"· Here can have up to 100,000 members\n· Chat anonymous\n· Please follow the group rules", nil)
    : NSLocalizedString(@"Messages to this chat and calls are now secured with peer-to-peer communication, end-to-end encryption.\nTap for more info >", "");
    messageText.messageType = 2;
    messageText.status = 1;
    
    OCTMessageAbstract *defaultMessage = [OCTMessageAbstract new];
    defaultMessage.chatUniqueIdentifier = chat.uniqueIdentifier;
    defaultMessage.dateInterval = 1;
    defaultMessage.readed = YES;
    defaultMessage.messageText = messageText;
    [self.realm addObject:defaultMessage];
}

- (OCTChat *)getGroupChatWithGroupNumber:(NSInteger)groupNumber
{
    __block OCTChat *chat = nil;
    dispatch_sync(self.queue, ^{
        chat = [[OCTChat objectsInRealm:self.realm where:@"groupNumber == %ld", groupNumber] firstObject];
        
    });
    return chat;
}

- (OCTChat *)getOrCreateChatWithGroupNumber:(NSInteger)groupNumber
{
    __block OCTChat *chat = nil;
    
    dispatch_sync(self.queue, ^{
        chat = [[OCTChat objectsInRealm:self.realm where:@"groupNumber == %ld", groupNumber] firstObject];
        
        if (chat) {
            return;
        }
        
        chat = [OCTChat new];
        chat.lastActivityDateInterval = [[NSDate date] timeIntervalSince1970];
        chat.isGroup = YES;
        chat.groupNumber = groupNumber;
        
        [self.realm beginWriteTransaction];
        [self.realm addObject:chat];
        [self addDefaultTipMessageToChat:chat];
        [self.realm commitWriteTransaction];
    });
    
    return chat;
}

- (OCTCall *)createCallWithChat:(OCTChat *)chat status:(OCTCallStatus)status
{
    __block OCTCall *call = nil;

    dispatch_sync(self.queue, ^{

        call = [[OCTCall objectsInRealm:self.realm where:@"chat == %@", chat] firstObject];

        if (call) {
            return;
        }

        OCTLogInfo(@"creating call with chat %@", chat);

        call = [OCTCall new];
        call.status = status;
        call.chat = chat;

        [self.realm beginWriteTransaction];
        [self.realm addObject:call];
        [self.realm commitWriteTransaction];
    });

    return call;
}

- (OCTCall *)getCurrentCallForChat:(OCTChat *)chat
{
    __block OCTCall *call = nil;

    dispatch_sync(self.queue, ^{

        call = [[OCTCall objectsInRealm:self.realm where:@"chat == %@", chat] firstObject];
    });

    return call;
}

- (void)markChatMessagesAsRead:(OCTChat *)chat
{
    NSParameterAssert(chat);
    
    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];
        
        RLMResults *messages = [OCTMessageAbstract objectsInRealm:self.realm where:@"chatUniqueIdentifier == %@ AND readed == NO", chat.uniqueIdentifier];
        
        for (OCTMessageAbstract *message in messages) {
            message.readed = YES;
        }
        
        [self.realm commitWriteTransaction];
    });
}

- (void)markChatMessagesAsRead:(NSString *)chatId db:(RLMRealm *)db
{
    [db beginWriteTransaction];
    
    RLMResults *messages = [OCTMessageAbstract objectsInRealm:db where:@"chatUniqueIdentifier == %@ AND readed == NO", chatId];
    
    for (OCTMessageAbstract *message in messages) {
        message.readed = YES;
    }
    
    [db commitWriteTransaction];
}

- (void)removeMessages:(NSArray<OCTMessageAbstract *> *)messages withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    NSParameterAssert(messages);

    OCTLogInfo(@"removing messages %lu", (unsigned long)messages.count);

    dispatch_sync(self.queue, ^{
        [self.realm beginWriteTransaction];

        NSMutableSet *changedChats = [NSMutableSet new];
        for (OCTMessageAbstract *message in messages) {
            [changedChats addObject:message.chatUniqueIdentifier];
        }

        [self removeMessagesWithSubmessages:messages];

        for (NSString *chatUniqueIdentifier in changedChats) {
            RLMResults *messages = [OCTMessageAbstract objectsInRealm:self.realm where:@"chatUniqueIdentifier == %@", chatUniqueIdentifier];
            messages = [messages sortedResultsUsingKeyPath:@"dateInterval" ascending:YES];

            OCTChat *chat = [OCTChat objectInRealm:self.realm forPrimaryKey:chatUniqueIdentifier];
            chat.lastMessage = messages.lastObject;
        }
        
        if (tokens.count > 0) {
            [self.realm commitWriteTransactionWithoutNotifying:tokens error:nil];
        } else {
            [self.realm commitWriteTransaction];
        }
    });
}

- (void)removeAllMessagesInChat:(OCTChat *)chat removeChat:(BOOL)removeChat
{
    NSParameterAssert(chat);

    OCTLogInfo(@"removing chat with all messages %@", chat);

    dispatch_sync(self.queue, ^{
        RLMResults *messages = [OCTMessageAbstract objectsInRealm:self.realm where:@"chatUniqueIdentifier == %@", chat.uniqueIdentifier];

        [self.realm beginWriteTransaction];

        [self removeMessagesWithSubmessages:messages];
        if (removeChat) {
            [self.realm deleteObject:chat];
        }

        [self.realm commitWriteTransaction];
    });
}

- (void)convertAllCallsToMessages
{
    RLMResults *calls = [OCTCall allObjectsInRealm:self.realm];

    OCTLogInfo(@"removing %lu calls", (unsigned long)calls.count);

    for (OCTCall *call in calls) {
        [self addMessageCall:call];
    }

    [self.realm beginWriteTransaction];
    [self.realm deleteObjects:calls];
    [self.realm commitWriteTransaction];
}

- (OCTMessageAbstract *)addMessageWithText:(NSString *)text
                                      type:(OCTToxMessageType)type
                                      chat:(OCTChat *)chat
                                    sender:(OCTObject *)sender
                                 messageId:(OCTToxMessageId)messageId
                              dateInterval:(NSTimeInterval)dateInterval
                                    status:(NSInteger)status
                          withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    NSParameterAssert(text);

    OCTLogInfo(@"adding messageText to chat %@", chat);

    OCTMessageText *messageText = [OCTMessageText new];
    messageText.text = text;
    messageText.status = status;
    messageText.type = type;
    messageText.messageId = messageId;

    return [self addMessageAbstractWithChat:chat sender:sender messageText:messageText messageFile:nil messageCall:nil dateInterval:dateInterval withoutNotifying:tokens];
}

- (OCTMessageAbstract *)createMessageWithText:(NSString *)text
                                         type:(OCTToxMessageType)type
                                         chat:(OCTChat *)chat
                                       sender:(OCTObject *)sender
                                    messageId:(OCTToxMessageId)messageId
                                 dateInterval:(NSTimeInterval)dateInterval
                                       status:(NSInteger)status
                                        realm:(RLMRealm *)realm
{
    NSParameterAssert(text);
    
    OCTLogInfo(@"adding messageText to chat %@", chat);
    
    OCTMessageText *messageText = [OCTMessageText new];
    messageText.text = text;
    messageText.status = status;
    messageText.type = type;
    messageText.messageId = messageId;
    
    OCTMessageAbstract *messageAbstract = [OCTMessageAbstract new];
    messageAbstract.dateInterval = dateInterval == 0 ? [[NSDate date] timeIntervalSince1970] : dateInterval;
    messageAbstract.senderUniqueIdentifier = sender.uniqueIdentifier;
    messageAbstract.chatUniqueIdentifier = chat.uniqueIdentifier;
    messageAbstract.messageText = messageText;
    
    if (messageAbstract.senderUniqueIdentifier == nil) {
        messageAbstract.readed = YES;
    }
    
    if ([sender isKindOfClass:[OCTFriend class]]) {
        messageAbstract.senderPublicKey = ((OCTFriend *)sender).publicKey;
    } else if ([sender isKindOfClass:[OCTPeer class]]) {
        messageAbstract.senderPublicKey = ((OCTPeer *)sender).publicKey;
    }
    
    if (messageAbstract.dateInterval > chat.lastActivityDateInterval) {
        [self updateObject:chat realm:realm withBlock:^(OCTChat *theChat) {
            theChat.lastMessage = messageAbstract;
            theChat.lastActivityDateInterval = messageAbstract.dateInterval;
        }];
    }
    
    return messageAbstract;
}

- (OCTMessageAbstract *)addOtherMessageWithText:(NSString *)text
                                           type:(OCTToxMessageType)type
                                           chat:(OCTChat *)chat
                                    messageType:(NSInteger)messageType
                                      messageId:(OCTToxMessageId)messageId
{
    NSParameterAssert(text);
    
    OCTLogInfo(@"adding messageText to chat %@", chat);
    
    OCTMessageText *messageText = [OCTMessageText new];
    messageText.text = text;
    messageText.status = 2;
    messageText.type = type;
    messageText.messageId = messageId;
    messageText.messageType = messageType;
    
    return [self addMessageAbstractWithChat:chat sender:nil messageText:messageText messageFile:nil messageCall:nil dateInterval:0 withoutNotifying:nil];
}

- (OCTMessageAbstract *)addMessageWithFileNumber:(OCTToxFileNumber)fileNumber
                                        fileType:(OCTMessageFileType)fileType
                                        fileSize:(OCTToxFileSize)fileSize
                                        fileName:(NSString *)fileName
                                        filePath:(NSString *)filePath
                                         fileUTI:(NSString *)fileUTI
                                            chat:(OCTChat *)chat
                                          sender:(OCTObject *)sender
                                    dateInterval:(NSTimeInterval)dateInterval
                                       isOffline:(BOOL)isOffline
                                       messageId:(OCTToxMessageId)messageId
                                        opened:(BOOL)opened
{
    OCTMessageFile *messageFile = [OCTMessageFile new];
    messageFile.internalFileNumber = fileNumber;
    messageFile.fileType = fileType;
    messageFile.fileSize = fileSize;
    messageFile.fileName = fileName;
    [messageFile internalSetFilePath:filePath];
    messageFile.fileUTI = fileUTI;
    messageFile.isOffline = isOffline;
    messageFile.messageId = messageId;
    messageFile.opened = opened;
    
    return [self addMessageAbstractWithChat:chat sender:sender messageText:nil messageFile:messageFile messageCall:nil dateInterval:dateInterval withoutNotifying:nil];
}

- (OCTMessageAbstract *)addMessageCall:(OCTCall *)call
{
    OCTLogInfo(@"adding messageCall to call %@", call);

    OCTMessageCallEvent event;
    switch (call.status) {
        case OCTCallStatusDialing:
        case OCTCallStatusRinging:
            event = OCTMessageCallEventUnanswered;
            break;
        case OCTCallStatusActive:
            event = OCTMessageCallEventAnswered;
            break;
    }

    OCTMessageCall *messageCall = [OCTMessageCall new];
    messageCall.callDuration = call.callDuration;
    messageCall.callEvent = event;

    return [self addMessageAbstractWithChat:call.chat sender:call.caller messageText:nil messageFile:nil messageCall:messageCall dateInterval:0 withoutNotifying:nil];
}

- (BOOL)checkMessageIsExisted:(OCTToxMessageId)messageId chat:(OCTChat *)chat checkFile:(BOOL)checkFile
{
    if (chat == nil) {
        return nil;
    }
    
    NSPredicate *textPredicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld AND tokMessageType == %ld",
                                  chat.uniqueIdentifier, messageId, TokMessageTypeNormal];
    NSPredicate *filePredicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageFile.messageId == %lld AND tokMessageType == %ld",
                                  chat.uniqueIdentifier, messageId, TokMessageTypeNormal];
    
    NSPredicate *predicate = checkFile ? filePredicate : textPredicate;
    
    RLMResults *results = [self objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    return results.count > 0;
}

- (BOOL)friendAcceptRequest:(NSString *)publicKey
{
    NSParameterAssert(publicKey);
    
    OCTFriend *friend = [self friendWithPublicKey:publicKey];
    if (friend == nil) {
        return NO;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"publicKey == %@", publicKey];
    OCTFriendRequest *request = [self objectsWithClass:[OCTFriendRequest class] predicate:predicate].firstObject;
    if (request) {
        [self deleteObject:request];
    }
    
    if (friend.friendState != 0) {
        [self updateObject:friend withBlock:^(OCTFriend *theFriend) {
            theFriend.friendState = 0;
        }];
    }
    
    return YES;
}

- (BOOL)friendAcceptRequest:(NSString *)publicKey db:(RLMRealm *)db
{
    NSParameterAssert(publicKey);
    
    OCTFriend *friend = [self friendWithPublicKey:publicKey db:db];
    if (friend == nil) {
        return NO;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"publicKey == %@", publicKey];
    OCTFriendRequest *request = [OCTFriendRequest objectsInRealm:db withPredicate:predicate].firstObject;
    [db beginWriteTransaction];
    if (request) {
        [db deleteObject:request];
    }
    if (friend.friendState != 0) {
        friend.friendState = 0;
    }
    [db commitWriteTransaction];
    
    return YES;
}

- (void)addFriendRequestWithMessage:(NSString *)message publicKey:(NSString *)publicKey isOutgoing:(BOOL)isOutgoing
{
    OCTRealmManager *realmManager = self;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"publicKey == %@", publicKey];
    RLMResults *results = [realmManager objectsWithClass:[OCTFriendRequest class] predicate:predicate];
    if (results.count > 0) {
        // friendRequest already exists
        return;
    }
    
    results = [realmManager objectsWithClass:[OCTFriend class] predicate:predicate];
    if (results.count > 0) {
        // friend with such publicKey already exists
        return;
    }
    
    OCTFriendRequest *request = [OCTFriendRequest new];
    request.publicKey = publicKey;
    request.message = message;
    request.dateInterval = [[NSDate date] timeIntervalSince1970];
    request.isOutgoing = isOutgoing;
    
    [realmManager addObject:request];
}

#pragma mark -  Private

+ (RLMMigrationBlock)realmMigrationBlock
{
    return ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
        if (oldSchemaVersion < 2) {
            [self doMigrationVersion1:migration];
        }
        if (oldSchemaVersion < 3) {
            [self doMigrationVersion2:migration];
        }
        if (oldSchemaVersion < 4) {
            [self doMigrationVersion3:migration];
        }
        if (oldSchemaVersion < 5) {
            [self doMigrationVersion4:migration];
        }
        if (oldSchemaVersion < 7) {
            [self doMigrationVersion6:migration];
        }
        if (oldSchemaVersion < 8) {
            [self doMigrationVersion7:migration];
        }
        if (oldSchemaVersion < 9) {
            [self doMigrationVersion8:migration];
        }
        if (oldSchemaVersion < 10) {
            [self doMigrationVersion9:migration];
        }
        if (oldSchemaVersion < 11) {
            [self doMigrationVersion10:migration];
        }
        if (oldSchemaVersion < 12) {
            [self doMigrationVersion11:migration];
        }
        if (oldSchemaVersion < 13) {
            [self doMigrationVersion12:migration];
        }
        if (oldSchemaVersion < 14) {
            [self doMigrationVersion13:migration];
        }
        if (oldSchemaVersion < 15) {
            [self doMigrationVersion14:migration];
        }
    };
}

+ (void)doMigrationVersion1:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTFriend.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"clientVersion"] = @(0);
    }];
}

+ (void)doMigrationVersion2:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTMessageFile.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"duration"] = nil;
    }];
}

+ (void)doMigrationVersion3:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTFriend.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"supportOfflineMessage"] = @(NO);
    }];
}

+ (void)doMigrationVersion4:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTChat.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"ownerPublicKey"] = nil;
        newObject[@"groupStatus"] = @(0);
    }];
    
    [migration enumerateObjects:OCTMessageText.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"messageType"] = @(0);
    }];
}

+ (void)doMigrationVersion6:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTMessageFile.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"messageId"] = @(-1);
    }];
}

+ (void)doMigrationVersion7:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTMessageFile.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"expired"] = @(NO);
    }];
}

+ (void)doMigrationVersion8:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTChat.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"groupDescription"] = nil;
    }];
}

+ (void)doMigrationVersion9:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTChat.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"groupMemebersCount"] = @(0);
        newObject[@"groupType"] = @(0);
    }];
}

+ (void)doMigrationVersion10:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTChat.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"groupId"] = nil;
    }];
}

+ (void)doMigrationVersion11:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTFriendRequest.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"status"] = @(0);
        newObject[@"isOutgoing"] = @(NO);
    }];
    [migration enumerateObjects:OCTFriend.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"friendState"] = @(0);
    }];
}

+ (void)doMigrationVersion12:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTChat.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"lastMessageId"] = @(-1);
        newObject[@"leftCount"] = @(0);
    }];
}

+ (void)doMigrationVersion13:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTMessageAbstract.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"tokMessageType"] = @(0);
    }];
}

+ (void)doMigrationVersion14:(RLMMigration *)migration
{
    [migration enumerateObjects:OCTFriend.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"blocked"] = @(NO);
    }];
    [migration enumerateObjects:OCTPeer.className block:^(RLMObject *oldObject, RLMObject *newObject) {
        newObject[@"blocked"] = @(NO);
    }];
}

/**
 * Only one of messageText, messageFile or messageCall can be non-nil.
 */
- (OCTMessageAbstract *)addMessageAbstractWithChat:(OCTChat *)chat
                                            sender:(OCTObject *)sender
                                       messageText:(OCTMessageText *)messageText
                                       messageFile:(OCTMessageFile *)messageFile
                                       messageCall:(OCTMessageCall *)messageCall
                                      dateInterval:(NSTimeInterval)dateInterval
                                  withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    NSParameterAssert(chat);

    NSAssert( (messageText && ! messageFile && ! messageCall) ||
              (! messageText && messageFile && ! messageCall) ||
              (! messageText && ! messageFile && messageCall),
              @"Wrong options passed. Only one of messageText, messageFile or messageCall should be non-nil.");

    OCTMessageAbstract *messageAbstract = [OCTMessageAbstract new];
    messageAbstract.dateInterval = dateInterval == 0 ? [[NSDate date] timeIntervalSince1970] : dateInterval;
    messageAbstract.senderUniqueIdentifier = sender.uniqueIdentifier;
    messageAbstract.chatUniqueIdentifier = chat.uniqueIdentifier;
    messageAbstract.messageText = messageText;
    messageAbstract.messageFile = messageFile;
    messageAbstract.messageCall = messageCall;
    
    if (messageAbstract.senderUniqueIdentifier == nil || messageCall != nil) {
        messageAbstract.readed = YES;
    }
    
    if ([sender isKindOfClass:[OCTFriend class]]) {
        messageAbstract.senderPublicKey = ((OCTFriend *)sender).publicKey;
    } else if ([sender isKindOfClass:[OCTPeer class]]) {
        messageAbstract.senderPublicKey = ((OCTPeer *)sender).publicKey;
    }
    
    [self addObject:messageAbstract withoutNotifying:tokens];
    
    if (messageAbstract.dateInterval > chat.lastActivityDateInterval) {
        [self updateObject:chat withBlock:^(OCTChat *theChat) {
            theChat.lastMessage = messageAbstract;
            theChat.lastActivityDateInterval = messageAbstract.dateInterval;
        }];
    }

    return messageAbstract;
}

// Delete an NSArray, RLMArray, or RLMResults of messages from this Realm.
- (void)removeMessagesWithSubmessages:(id)messages
{
    for (OCTMessageAbstract *message in messages) {
        if (message.messageText) {
            [self.realm deleteObject:message.messageText];
        }
        if (message.messageFile) {
            [self.realm deleteObject:message.messageFile];
        }
        if (message.messageCall) {
            [self.realm deleteObject:message.messageCall];
        }
    }

    [self.realm deleteObjects:messages];
}

#pragma mark - custom realm

- (OCTChat *)getOrCreateChatWithGroupNumber:(NSInteger)groupNumber realm:(RLMRealm *)realm
{
    OCTChat *chat = nil;
    chat = [[OCTChat objectsInRealm:realm where:@"groupNumber == %ld", groupNumber] firstObject];
    
    if (chat) {
        return chat;
    }
    
    chat = [OCTChat new];
    chat.lastActivityDateInterval = [[NSDate date] timeIntervalSince1970];
    chat.isGroup = YES;
    chat.groupNumber = groupNumber;
    
    [realm beginWriteTransaction];
    [realm addObject:chat];
    [self addDefaultTipMessageToChat:chat realm:realm];
    [realm commitWriteTransaction];
    return chat;
}

- (void)updateObject:(OCTObject *)object realm:(RLMRealm *)realm withBlock:(void (^)(id theObject))updateBlock
{
    NSParameterAssert(object);
    NSParameterAssert(updateBlock);
    
    OCTLogInfo(@"updateObject %@", object);
    
    [realm beginWriteTransaction];
    
    updateBlock(object);
    
    [realm commitWriteTransaction];
}

- (void)addDefaultTipMessageToChat:(OCTChat *)chat realm:(RLMRealm *)realm
{
    // Add default tip message
    OCTMessageText *messageText = [OCTMessageText new];
    messageText.text = chat.isGroup
    ? NSLocalizedString(@"· Here can have up to 100,000 members\n· Chat anonymous\n· Please follow the group rules", nil)
    : NSLocalizedString(@"Messages to this chat and calls are now secured with peer-to-peer communication, end-to-end encryption.\nTap for more info >", "");
    messageText.messageType = 2;
    messageText.status = 1;
    
    OCTMessageAbstract *defaultMessage = [OCTMessageAbstract new];
    defaultMessage.chatUniqueIdentifier = chat.uniqueIdentifier;
    defaultMessage.dateInterval = 1;
    defaultMessage.readed = YES;
    defaultMessage.messageText = messageText;
    [realm addObject:defaultMessage];
}

- (OCTMessageAbstract *)checkMessageIsExisted:(OCTToxMessageId)messageId chat:(OCTChat *)chat checkFile:(BOOL)checkFile realm:(RLMRealm *)realm
{
    if (chat == nil) {
        return nil;
    }
    
    NSPredicate *textPredicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld",
                                  chat.uniqueIdentifier, messageId];
    NSPredicate *filePredicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageFile.messageId == %lld",
                                  chat.uniqueIdentifier, messageId];
    
    NSPredicate *predicate = checkFile ? filePredicate : textPredicate;
    
    RLMResults *results =  [OCTMessageAbstract objectsInRealm:realm withPredicate:predicate];
    OCTMessageAbstract *message = [results firstObject];
    
    return message;
}

- (OCTPeer *)peerWithPeerPK:(NSString *)publicKey groupNumber:(NSInteger)groupNumber realm:(RLMRealm *)realm
{
    OCTPeer *peer = [[OCTPeer objectsInRealm:realm where:@"publicKey == %@ AND groupNumber == %ld", [publicKey uppercaseString], groupNumber] firstObject];
    return peer;
}

- (OCTChat *)getGroupChatWithGroupNumber:(NSInteger)groupNumber realm:(RLMRealm *)realm
{
    OCTChat *chat = [[OCTChat objectsInRealm:realm where:@"groupNumber == %ld", groupNumber] firstObject];
    return chat;
}

- (OCTMessageAbstract *)addOtherMessageWithText:(NSString *)text
                                           type:(OCTToxMessageType)type
                                           chat:(OCTChat *)chat
                                    messageType:(NSInteger)messageType
                                      messageId:(OCTToxMessageId)messageId
                                          realm:(RLMRealm *)realm

{
    NSParameterAssert(text);
    
    OCTLogInfo(@"adding messageText to chat %@", chat);
    
    OCTMessageText *messageText = [OCTMessageText new];
    messageText.text = text;
    messageText.status = 2;
    messageText.type = type;
    messageText.messageId = messageId;
    messageText.messageType = messageType;
    
    return [self addMessageAbstractWithChat:chat sender:nil messageText:messageText messageFile:nil messageCall:nil dateInterval:0 realm:realm];
}

- (OCTMessageAbstract *)addMessageAbstractWithChat:(OCTChat *)chat
                                            sender:(OCTObject *)sender
                                       messageText:(OCTMessageText *)messageText
                                       messageFile:(OCTMessageFile *)messageFile
                                       messageCall:(OCTMessageCall *)messageCall
                                      dateInterval:(NSTimeInterval)dateInterval
                                             realm:(RLMRealm *)realm
{
    NSParameterAssert(chat);
    
    NSAssert( (messageText && ! messageFile && ! messageCall) ||
             (! messageText && messageFile && ! messageCall) ||
             (! messageText && ! messageFile && messageCall),
             @"Wrong options passed. Only one of messageText, messageFile or messageCall should be non-nil.");
    
    OCTMessageAbstract *messageAbstract = [OCTMessageAbstract new];
    messageAbstract.dateInterval = dateInterval == 0 ? [[NSDate date] timeIntervalSince1970] : dateInterval;
    messageAbstract.senderUniqueIdentifier = sender.uniqueIdentifier;
    messageAbstract.chatUniqueIdentifier = chat.uniqueIdentifier;
    messageAbstract.messageText = messageText;
    messageAbstract.messageFile = messageFile;
    messageAbstract.messageCall = messageCall;
    
    if (messageAbstract.senderUniqueIdentifier == nil || messageCall != nil) {
        messageAbstract.readed = YES;
    }
    
    if ([sender isKindOfClass:[OCTFriend class]]) {
        messageAbstract.senderPublicKey = ((OCTFriend *)sender).publicKey;
    } else if ([sender isKindOfClass:[OCTPeer class]]) {
        messageAbstract.senderPublicKey = ((OCTPeer *)sender).publicKey;
    }
    
    [realm beginWriteTransaction];
    [realm addObject:messageAbstract];
    [realm commitWriteTransaction];
    
    if (messageAbstract.dateInterval > chat.lastActivityDateInterval) {
        [self updateObject:chat realm:realm withBlock:^(OCTChat *theChat) {
            theChat.lastMessage = messageAbstract;
            theChat.lastActivityDateInterval = messageAbstract.dateInterval;
        }];
    }
    
    return messageAbstract;
}

@end
