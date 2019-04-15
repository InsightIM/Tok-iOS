// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerChatsImpl.h"
#import "OCTTox.h"
#import "OCTTox+Private.h"
#import "OCTRealmManager.h"
#import "OCTMessageAbstract.h"
#import "OCTMessageText.h"
#import "OCTMessageFile.h"
#import "OCTChat.h"
#import "OCTPeer.h"
#import "OCTLogging.h"
#import "OCTSendMessageOperation.h"
#import "Message.pbobjc.h"
#import "OCTSettingsStorageObject.h"
#import "MessageOperationManager.h"

@interface OCTSubmanagerChatsImpl ()

@property (nonatomic, strong, readonly) NSOperationQueue *sendMessageQueue;
@property (nonatomic, strong, readonly) MessageOperationManager *messageOperationManager;
@end

@implementation OCTSubmanagerChatsImpl
@synthesize dataSource = _dataSource;

- (instancetype)init
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _sendMessageQueue = [NSOperationQueue new];
    _sendMessageQueue.maxConcurrentOperationCount = 1;

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
    
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    _messageOperationManager = [[MessageOperationManager alloc] initWithTox:tox realmManager:realmManager];
    
    [_messageOperationManager setSendingMessageToFailed];
}

#pragma mark - Public

- (OCTChat *)getChatWithFriend:(OCTFriend *)friend
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    
    OCTChat *chat = [realmManager getChatWithFriend:friend];
    
    return chat;
}

- (OCTChat *)getOrCreateChatWithFriend:(OCTFriend *)friend
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    
    OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
    
    return chat;
}

- (void)setIsMute:(BOOL)isMute inChat:(OCTChat *)chat
{
    [[self.dataSource managerGetRealmManager] updateObject:chat withBlock:^(OCTChat *theChat) {
        theChat.isMute = isMute;
    }];
}

- (void)markChatMessagesAsRead:(OCTChat *)chat
{
    [[self.dataSource managerGetRealmManager] markChatMessagesAsRead:chat];
}

- (void)setMessageReaded:(OCTMessageAbstract *)message
{
    if (message.readed) {
        return;
    }
    
    [[self.dataSource managerGetRealmManager] updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.readed = YES;
    }];
}

- (void)setMessageFileOpened:(OCTMessageAbstract *)message
{
    if (message.messageFile == nil || message.messageFile.opened == YES) {
        return;
    }
    
    [[self.dataSource managerGetRealmManager] updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.messageFile.opened = YES;
    }];
}

- (void)setMessageFileDuration:(NSString *)duration message:(OCTMessageAbstract *)message
{
    if (message.messageFile == nil || message.messageFile.duration == duration) {
        return;
    }
    
    [[self.dataSource managerGetRealmManager] updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.messageFile.duration = duration;
    }];
}

- (void)removeMessages:(NSArray<OCTMessageAbstract *> *)messages withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    [[self.dataSource managerGetRealmManager] removeMessages:messages withoutNotifying:tokens];
    [self.dataSource.managerGetNotificationCenter postNotificationName:kOCTScheduleFileTransferCleanupNotification object:nil];
}

- (void)removeAllMessagesInChat:(OCTChat *)chat removeChat:(BOOL)removeChat
{
    if (chat == nil) {
        return;
    }
    
    [[self.dataSource managerGetRealmManager] removeAllMessagesInChat:chat removeChat:removeChat];
    [self.dataSource.managerGetNotificationCenter postNotificationName:kOCTScheduleFileTransferCleanupNotification object:nil];
}

- (void)sendMessageToChat:(OCTChat *)chat
                     text:(NSString *)text
                     type:(OCTToxMessageType)type
             successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
             failureBlock:(void (^)(NSError *error))userFailureBlock
{
    NSParameterAssert(chat);
    NSParameterAssert(text);
    
    OCTFriend *friend = [chat.friends firstObject];
    OCTToxFriendNumber friendNumber = friend.friendNumber;
    
    if (friend.clientVersion > 0) {
        [_messageOperationManager sendText:text toFriendNumber:friendNumber inChat:chat messageType:type];
    } else {
        [self sendMessageUsingOldVersionToChat:chat text:text type:type successBlock:userSuccessBlock failureBlock:userFailureBlock];
    }
}

- (void)sendMessageUsingOldVersionToChat:(OCTChat *)chat
                                    text:(NSString *)text
                                    type:(OCTToxMessageType)type
                            successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
                            failureBlock:(void (^)(NSError *error))userFailureBlock
{
    NSParameterAssert(chat);
    NSParameterAssert(text);
    
    OCTFriend *friend = [chat.friends firstObject];
    OCTToxMessageType realType = type;
    OCTToxFriendNumber friendNumber = friend.friendNumber;
    
    __weak OCTSubmanagerChatsImpl *weakSelf = self;
    OCTSendMessageOperationSuccessBlock successBlock = ^(OCTToxMessageId messageId) {
        __strong OCTSubmanagerChatsImpl *strongSelf = weakSelf;
        
        OCTRealmManager *realmManager = [strongSelf.dataSource managerGetRealmManager];
        OCTMessageAbstract *message = [realmManager addMessageWithText:text type:realType chat:chat sender:nil messageId:messageId dateInterval:0 status:messageId < 0 ? 2 : 0];
        
        if (userSuccessBlock) {
            userSuccessBlock(message);
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (chat.isInvalidated) {
                return;
            }
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %llu",
                                      chat.uniqueIdentifier, messageId];
            
            RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
            
            OCTMessageAbstract *message = [results firstObject];
            
            if (! message) {
                return;
            }
            
            if (message.messageText.status == 0) {
                [realmManager updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
                    theMessage.messageText.status = 2;
                }];
            }
        });
    };
    
    OCTSendMessageOperationFailureBlock failureBlock = ^(NSError *error) {
        successBlock(-1);
    };
    
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTSendMessageOperation *operation = [[OCTSendMessageOperation alloc] initWithTox:tox
                                                                            messageId:0
                                                                         friendNumber:friendNumber
                                                                          messageType:realType
                                                                              message:text
                                                                              version:0
                                                                         successBlock:successBlock
                                                                         failureBlock:failureBlock];
    [self.sendMessageQueue addOperation:operation];
}

- (BOOL)setIsTyping:(BOOL)isTyping inChat:(OCTChat *)chat error:(NSError **)error
{
    NSParameterAssert(chat);

    OCTFriend *friend = [chat.friends firstObject];
    OCTTox *tox = [self.dataSource managerGetTox];

    return [tox setUserIsTyping:isTyping forFriendNumber:friend.friendNumber error:error];
}

#pragma mark -  NSNotification

- (void)friendConnectionStatusChangeNotification:(NSNotification *)notification
{
    OCTFriend *friend = notification.object;

    if (! friend) {
        OCTLogWarn(@"no friend received in notification %@, exiting", notification);
        return;
    }
    
    if (friend.isConnected) {
        [_messageOperationManager resendUndeliveredMessagesToFriend:friend];
    }
}

#pragma mark -  OCTToxDelegate

- (void)tox:(OCTTox *)tox friendMessage:(NSData *)messageData type:(OCTToxMessageType)type friendNumber:(OCTToxFriendNumber)friendNumber time:(NSTimeInterval)time
{
    switch (type) {
        case OCTToxMessageTypeNormal:
        case OCTToxMessageTypeAction: {
            NSString *msg = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            if (msg == nil) {
                return;
            }
            OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
            NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
            OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
            OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
            
            [realmManager addMessageWithText:msg type:type chat:chat sender:friend messageId:0 dateInterval:time status:1];
            break;
        }
        default:
            break;
    }
}

- (void)tox:(OCTTox *)tox messageDelivered:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %d",
                              chat.uniqueIdentifier, messageId];
    
    // messageId is reset on every launch, so we want to update delivered status on latest message.
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    results = [results sortedResultsUsingKeyPath:@"dateInterval" ascending:NO];
    
    OCTMessageAbstract *message = [results firstObject];
    
    if (! message) {
        return;
    }
    
    [realmManager updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.messageText.status = 1;
    }];
}

/* new message protocol */

- (void)tox:(OCTTox *)tox receivedMessage:(NSData *)messageData length:(NSInteger)length friendNumber:(OCTToxFriendNumber)friendNumber time:(NSTimeInterval)time
{
    FriendMessageReq *friendMessage = [FriendMessageReq parseFromData:messageData error:nil];
    if (friendMessage == nil) {
        return;
    }
    
    NSData *message = friendMessage.msg;
    uint64_t msgId = friendMessage.localMsgId;
    
    NSString *msg = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
    if (msg == nil || msgId == 0 || [msg isEqualToString:@""]) {
        return;
    }
    
    NSLog(@"[2.1] Received Message. \nId: %lld, friendNumber: %d, text: %@", msgId, friendNumber, msg);
    // send response
    [_messageOperationManager sendResponseMessage:msgId friendNumber:friendNumber message:msg time:time];
}

- (void)tox:(OCTTox *)tox receivedResponse:(NSData *)messageData length:(NSInteger)length friendNumber:(OCTToxFriendNumber)friendNumber time:(NSTimeInterval)time
{
    FriendMessageRes *response = [FriendMessageRes parseFromData:messageData error:nil];
    if (response == nil) {
        return;
    }
    
    OCTToxMessageId msgId = (OCTToxMessageId)response.localMsgId;
    
    NSLog(@"[1.2] Received Echo Message. \nId: %lld, friendNumber: %d", msgId, friendNumber);
    
    BOOL result = [self setMessageStatus:msgId friendNumber:friendNumber isSuccess:YES];
    [_messageOperationManager sendConfirmMessage:msgId friendNumber:friendNumber success:result];
}

- (void)tox:(OCTTox *)tox receivedConfirm:(NSData *)messageData length:(NSInteger)length friendNumber:(OCTToxFriendNumber)friendNumber time:(NSTimeInterval)time
{
    FriendMessageCfm *cfm = [FriendMessageCfm parseFromData:messageData error:nil];
    if (cfm == nil) {
        return;
    }
    OCTToxMessageId msgId = (OCTToxMessageId)cfm.localMsgId;
    
    BOOL success = cfm.sendStatus == 1;
    [self setMessageStatus:msgId friendNumber:friendNumber isSuccess:success];
    
    NSLog(@"[2.3] Received Confirm Message. \nId: %lld, friendNumber: %d, result: %@", msgId, friendNumber, success ? @"Success" : @"Failure");
}

- (BOOL)setMessageStatus:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber isSuccess:(BOOL)isSuccess
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld", chat.uniqueIdentifier, messageId];
    
    // messageId is reset on every launch, so we want to update delivered status on latest message.
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    results = [results sortedResultsUsingKeyPath:@"dateInterval" ascending:NO];
    
    OCTMessageAbstract *message = [results firstObject];
    
    if (! message) {
        return NO;
    }
    
    if (message.messageText.status == 1) {
        return YES;
    }
    
    if (message.messageText.status == 2) {
        return NO;
    }
    
    [realmManager updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.messageText.status = isSuccess ? 1 : 2;
    }];
    
    return isSuccess;
}

@end
