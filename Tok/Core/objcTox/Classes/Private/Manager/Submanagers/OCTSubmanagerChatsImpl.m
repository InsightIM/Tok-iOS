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
#import "OCTSendOfflineMessageOperation.h"
#import "OCTSendGroupMessageOperation.h"
#import "OCTSendStrangerMessageOperation.h"

#define MESSAGE_TYPE_GROUP_TEXT_MESSAGE    0
#define MESSAGE_TYPE_GROUP_FILE_MESSAGE    1
#define MESSAGE_TYPE_GROUP_INVITE_NOTICE    3
#define MESSAGE_TYPE_GROUP_LEAVE_NOTICE     11
#define MESSAGE_TYPE_GROUP_KICKOUT_NOTICE   13
#define MESSAGE_TYPE_GROUP_DISSMISS_NOTICE  16

@interface OCTSubmanagerChatsImpl ()

@property (nonatomic, copy) OCTGroupMessageSuccessBlock createSuccessBlock;
@property (nonatomic, copy) OCTGroupMessageFailureBlock createFailureBlock;
@property (nonatomic, strong) dispatch_queue_t groupMessageDispatchQueue;
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
    
    _groupMessageDispatchQueue = dispatch_queue_create("com.insight.groupMessage", DISPATCH_QUEUE_SERIAL);
    
    return self;
}

- (void)dealloc
{
    [self.dataSource.managerGetNotificationCenter removeObserver:self];
}

- (void)configure
{
//    [self.dataSource.managerGetNotificationCenter addObserver:self
//                                                     selector:@selector(friendConnectionStatusChangeNotification:)
//                                                         name:kOCTFriendConnectionStatusChangeNotification
//                                                       object:nil];
    
    [self.dataSource.managerGetNotificationCenter addObserver:self
                                                     selector:@selector(sendOfflineFriendRequestNotification:)
                                                         name:kOCTSendOfflineFriendRequestNotification object:nil];
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

- (void)setIsMute:(BOOL)isMute inChat:(OCTChat *)chat withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens
{
    if (chat.isMute == isMute) {
        return;
    }
    [[self.dataSource managerGetRealmManager] updateObject:chat withBlock:^(OCTChat *theChat) {
        theChat.isMute = isMute;
    } withoutNotifying:tokens];
    if (chat.isGroup) {
        [self setMuteGroupWithGroupNumber:chat.groupNumber isMute:isMute];
    }
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
    
    if ([self shouldSendOfflineMessageToChat:chat text:text type:type successBlock:userSuccessBlock failureBlock:userFailureBlock]) {
        return;
    }
    
    [self sendNormalMessageToChat:chat text:text successBlock:userSuccessBlock failureBlock:userFailureBlock];
}

- (BOOL)setIsTyping:(BOOL)isTyping inChat:(OCTChat *)chat error:(NSError **)error
{
    NSParameterAssert(chat);
    
    OCTFriend *friend = [chat.friends firstObject];
    OCTTox *tox = [self.dataSource managerGetTox];
    
    return [tox setUserIsTyping:isTyping forFriendNumber:friend.friendNumber error:error];
}

- (void)queryFriendIsSupportOfflineMessage:(OCTFriend *)friend
{
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTToxFriendNumber botFriendNumber = [tox friendNumberWithPublicKey:botPublicKey error:nil];
    
    QueryFriendReq *req = [QueryFriendReq new];
    req.pk = [friend.publicKey dataUsingEncoding:NSUTF8StringEncoding];
    OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:tox
                                                                                                       cmd:OCTToxMessageOfflineCmdQueryRequest
                                                                                           botFriendNumber:botFriendNumber
                                                                                                   message:[req data]];
    [self.sendMessageQueue addOperation:operation];
}

- (void)uploadPushToken:(NSString *)token
{
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTToxFriendNumber botFriendNumber = [tox friendNumberWithPublicKey:botPublicKey error:nil];
    
    DeviceUpdateReq *req = [DeviceUpdateReq new];
    req.type = 1;
    req.identifier = [token dataUsingEncoding:NSUTF8StringEncoding];
    
    OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:tox
                                                                                                       cmd:OCTToxMessageOfflineCmdPushToken
                                                                                           botFriendNumber:botFriendNumber
                                                                                                   message:[req data]];
    [self.sendMessageQueue addOperation:operation];
}

- (void)sendOfflineFriendAcceptRequestWithPublicKey:(NSString *)publicKey
{
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        return;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    if (bot.isConnected == NO) {
        return;
    }
    
    OCTToxFriendNumber botFriendNumber = bot.friendNumber;
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTToxMessageId messageId = [tox generateMessageId];
    
    OfflineMessageReq *model = [OfflineMessageReq new];
    model.localMsgId = messageId;
    model.toPk = [publicKey dataUsingEncoding:NSUTF8StringEncoding];
    model.msgType = 3;
    
    NSData *data = [model data];
    
    OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc]
                                                 initOfflineWithTox:tox
                                                 cmd:OCTToxMessageOfflineCmdSend
                                                 messageId:messageId
                                                 botFriendNumber:botFriendNumber
                                                 message:data
                                                 successBlock:nil
                                                 failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

#pragma mark -  NSNotification

//- (void)friendConnectionStatusChangeNotification:(NSNotification *)notification
//{
//    OCTFriend *friend = notification.object;
//
//    if (! friend) {
//        OCTLogWarn(@"no friend received in notification %@, exiting", notification);
//        return;
//    }
//
//    if (friend.isConnected) {
//
//    }
//}

- (void)sendOfflineFriendRequestNotification:(NSNotification *)notification
{
    OCTFriend *friend = notification.object;
    NSString *message = notification.userInfo[@"message"];
    
    if (! friend) {
        OCTLogWarn(@"no friend received in notification %@, exiting", notification);
        return;
    }
    
    [self sendOfflineFriendRequestMessage:friend.friendNumber publicKey:friend.publicKey message:message];
}

#pragma mark -  OCTToxDelegate

- (void)tox:(OCTTox *)tox friendMessage:(NSData *)messageData type:(OCTToxMessageType)type friendNumber:(OCTToxFriendNumber)friendNumber
{
    switch (type) {
        case OCTToxMessageTypeNormal:
        case OCTToxMessageTypeAction: {
            if (friendNumber == [self findFriendBot].friendNumber) {
                [self handleFindStrangerMessage:messageData];
                return;
            }
            
            NSString *msg = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            if (msg == nil) {
                return;
            }
            OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
            NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
            OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
            OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
            
            [realmManager addMessageWithText:msg type:type chat:chat sender:friend messageId:0 dateInterval:0 status:1 withoutNotifying:nil];
            break;
        }
        default:
            break;
    }
}

- (void)tox:(OCTTox *)tox messageDelivered:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber
{
    NSDictionary *userInfo = @{
                               @"messageId": @(messageId),
                               @"friendNumber": @(friendNumber)
                               };
    [NSNotificationCenter.defaultCenter postNotificationName:kOCTMessageDelivedNotification object:nil userInfo:userInfo];
}

#pragma mark - Private

- (NSArray<NSString *> *)splitMessage:(NSString *)text maxLength:(NSUInteger)maxLength
{
    NSUInteger chunkSize = maxLength;
    NSUInteger length = text.length;
    NSUInteger offset = 0;
    
    NSMutableArray<NSString *> *splitTexts = @[].mutableCopy;
    do {
        NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
        NSString *chunk = [text substringWithRange:NSMakeRange(offset, thisChunkSize)];
        [splitTexts addObject:chunk];
        
        offset += thisChunkSize;
    } while (offset < length);
    
    return splitTexts;
}

- (BOOL)shouldSendOfflineMessageToChat:(OCTChat *)chat
                                  text:(NSString *)text
                                  type:(OCTToxMessageType)type
                          successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
                          failureBlock:(void (^)(NSError *error))userFailureBlock
{
    OCTFriend *friend = [chat.friends firstObject];
    OCTToxFriendNumber friendNumber = friend.friendNumber;
    if (friend.isConnected) {
        return NO;
    }
    
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        return NO;
    }
    
    if (friend.supportOfflineMessage == NO) {
        return NO;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    if (bot.isConnected == NO) {
        return NO;
    }
    
    OCTToxFriendNumber botFriendNumber = bot.friendNumber;
    
    NSArray<NSString *> *splitTexts = [self splitMessage:text maxLength:kOCTToxMaxOfflineMessageLength / 4.0];
    for (NSString *splitText in splitTexts) {
        __weak OCTSubmanagerChatsImpl *weakSelf = self;
        OCTSendMessageOperationSuccessBlock successBlock = ^(OCTToxMessageId messageId) {
            __strong OCTSubmanagerChatsImpl *strongSelf = weakSelf;
            
            OCTRealmManager *realmManager = [strongSelf.dataSource managerGetRealmManager];
            OCTMessageAbstract *message = [realmManager addMessageWithText:splitText type:type chat:chat sender:nil messageId:messageId dateInterval:0 status:messageId < 0 ? 2 : 0 withoutNotifying:nil];
            
            if (userSuccessBlock) {
                userSuccessBlock(message);
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (chat.isInvalidated) {
                    return;
                }
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld",
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
        
        OCTToxMessageId messageId = [tox generateMessageId];
        NSData *cryptoMessage = [tox encryptOfflineMessage:friendNumber message:splitText];
        
        OfflineMessageReq *model = [OfflineMessageReq new];
        model.localMsgId = messageId;
        model.toPk = [friend.publicKey dataUsingEncoding:NSUTF8StringEncoding];
        model.cryptoMessage = cryptoMessage;
        
        NSData *messageData = [model data];
        
        OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:tox
                                                                                                           cmd:OCTToxMessageOfflineCmdSend
                                                                                                     messageId:messageId
                                                                                               botFriendNumber:botFriendNumber
                                                                                                       message:messageData
                                                                                                  successBlock:successBlock
                                                                                                  failureBlock:failureBlock];
        
        [self.sendMessageQueue addOperation:operation];
    }
    
    return YES;
}

- (void)sendNormalMessageToChat:(OCTChat *)chat
                           text:(NSString *)text
                   successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
                   failureBlock:(void (^)(NSError *error))userFailureBlock
{
    NSParameterAssert(chat);
    NSParameterAssert(text);
    
    OCTFriend *friend = [chat.friends firstObject];
    OCTToxMessageType type = OCTToxMessageTypeNormal;
    OCTToxFriendNumber friendNumber = friend.friendNumber;
    
    NSArray<NSString *> *splitTexts = [self splitMessage:text maxLength:kOCTToxMaxMessageLength / 4.0];
    for (NSString *splitText in splitTexts) {
        __weak OCTSubmanagerChatsImpl *weakSelf = self;
        OCTSendMessageOperationSuccessBlock successBlock = ^(OCTToxMessageId messageId) {
            __strong OCTSubmanagerChatsImpl *strongSelf = weakSelf;
            
            OCTRealmManager *realmManager = [strongSelf.dataSource managerGetRealmManager];
            OCTMessageAbstract *message = [realmManager addMessageWithText:splitText type:type chat:chat sender:nil messageId:messageId dateInterval:0 status:messageId < 0 ? 2 : 0 withoutNotifying:nil];
            
            if (userSuccessBlock) {
                userSuccessBlock(message);
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (chat.isInvalidated) {
                    return;
                }
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld",
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
                    
                    if (userFailureBlock) {
                        userFailureBlock(nil);
                    }
                }
            });
        };
        
        OCTSendMessageOperationFailureBlock failureBlock = ^(NSError *error) {
            successBlock(-1);
            
            if (userFailureBlock) {
                userFailureBlock(error);
            }
        };
        
        OCTTox *tox = [self.dataSource managerGetTox];
        OCTSendMessageOperation *operation = [[OCTSendMessageOperation alloc] initWithTox:tox
                                                                             friendNumber:friendNumber
                                                                              messageType:type
                                                                                  message:splitText
                                                                             successBlock:successBlock
                                                                             failureBlock:failureBlock];
        [self.sendMessageQueue addOperation:operation];
    }
}

- (void)sendOfflineFriendRequestMessage:(OCTToxFriendNumber)friendNumber
                              publicKey:(NSString *)publicKey
                                message:(NSString *)message
{
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        return;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    if (bot.isConnected == NO) {
        return;
    }
    
    OCTToxFriendNumber botFriendNumber = bot.friendNumber;
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTToxMessageId messageId = [tox generateMessageId];
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    
    OfflineMessageReq *model = [OfflineMessageReq new];
    model.localMsgId = messageId;
    model.toPk = [publicKey dataUsingEncoding:NSUTF8StringEncoding];
    model.cryptoMessage = messageData;
    model.msgType = 2;
    
    NSData *data = [model data];
    
    OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc]
                                                 initOfflineWithTox:tox
                                                 cmd:OCTToxMessageOfflineCmdSend
                                                 messageId:messageId
                                                 botFriendNumber:botFriendNumber
                                                 message:data
                                                 successBlock:nil
                                                 failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

#pragma mark - Group
#pragma mark - Group Private

- (OCTFriend *)groupBot
{
    NSString *botPublicKey = [self.dataSource getGroupMessageBotPublicKey];
    if (botPublicKey == nil) {
        return nil;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    return bot;
}

- (void)handleGroupCreateWithData:(NSData *)messageData
{
    NSError *error;
    GroupCreateRes *model = [GroupCreateRes parseFromData:messageData error:&error];
    if (error || model.code != 1) {
        if (self.createFailureBlock) {
            self.createFailureBlock(error);
            self.createFailureBlock = nil;
        }
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getOrCreateChatWithGroupNumber:model.groupId];
    [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
        theChat.title = [[NSString alloc] initWithData:model.groupName encoding:NSUTF8StringEncoding];
    }];
    
    if (self.createSuccessBlock) {
        self.createSuccessBlock(chat);
        self.createSuccessBlock = nil;
    }
}

- (void)handleGroupInviteWithData:(NSData *)messageData
                        messageId:(OCTToxMessageId)messageId
                             chat:(OCTChat *)chat
{
    NSError *error;
    GroupInviteNotice *model = [GroupInviteNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    NSString *inviterPk = [[NSString alloc] initWithData:model.inviterPk encoding:NSUTF8StringEncoding];
    NSString *inviteePk = [[NSString alloc] initWithData:model.inviteePk encoding:NSUTF8StringEncoding];
    
    NSString *inviter = [[NSString alloc] initWithData:model.inviterName encoding:NSUTF8StringEncoding];
    NSString *invitee = [[NSString alloc] initWithData:model.inviteeName encoding:NSUTF8StringEncoding];
    
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    RLMRealm *realm = [realmManager database];
    
    if (model.code == 1) {
        if (chat == nil) {
            chat = [realmManager getOrCreateChatWithGroupNumber:model.groupId realm:realm];
        }
        
        NSString *selfPublicKey = tox.publicKey;
        NSString *message;
        if (inviterPk == nil || [inviterPk isEqualToString:@""]) {
            if ([inviteePk.uppercaseString isEqualToString:selfPublicKey]) {
                message = NSLocalizedString(@"You joined group", nil);
            } else {
                message = [NSString stringWithFormat:NSLocalizedString(@"%@ joined group", nil), invitee];
            }
        } else if ([inviteePk.uppercaseString isEqualToString:selfPublicKey]) {
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ invited you to the group chat", nil), inviter];
            [realmManager updateObject:chat realm:realm withBlock:^(OCTChat *theChat) {
                theChat.groupStatus = 0;
            }];
        } else if ([inviterPk.uppercaseString isEqualToString:selfPublicKey]) {
            message = [NSString stringWithFormat:NSLocalizedString(@"You invited %@ to the group chat", nil), invitee];
        } else {
            message = [NSString stringWithFormat:NSLocalizedString(@"%@ invited %@ to the group chat", nil), inviter, invitee];
        }
        [realmManager addOtherMessageWithText:message type:OCTToxMessageTypeGroup chat:chat messageType:1 messageId:messageId realm:realm];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [realmManager refresh]; // force update between threads
            OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
            [[NSNotificationCenter defaultCenter] postNotificationName:kOCTGroupInviteReceivedNotification
                                                                object:chat];
        });
    } else if (model.code == 2) { // cannot join group, because be blocked
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kOCTGroupInviteReceivedNotification
                                                                object:nil];
        });
    } else {
        OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId realm:realm];
        if (chat == nil) {
            return;
        }
        OCTFriend *friend = [[OCTFriend objectsInRealm:realm where:@"publicKey == %@", inviteePk.uppercaseString] firstObject];
        if (friend == nil) {
            return;
        }
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@'s app version is too low to be invited", nil), friend.nickname];
        [realmManager addOtherMessageWithText:message type:OCTToxMessageTypeGroup chat:chat messageType:1 messageId:messageId realm:realm];
    }
}

- (void)handleGroupMessageWithTox:(OCTTox *)tox botFriendNumber:(OCTToxFriendNumber)botFriendNumber data:(NSData *)messageData
{
    dispatch_async(_groupMessageDispatchQueue, ^{
        NSError *error;
        GroupMessagePullRes *model = [GroupMessagePullRes parseFromData:messageData error:&error];
        if (error) {
            return;
        }
        
        NSInteger groupNumber = model.groupId;
        NSLog(@"Handle group message, group id：%ld, msgArray:%@, leftCount: %u", (long)groupNumber, model.msgArray, model.leftCount);
        
        OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
        RLMRealm *realm = [realmManager database];
        OCTChat *chat = [realmManager getOrCreateChatWithGroupNumber:groupNumber realm:realm];
        
        // if chat group status is disabled, update to enable
        if (chat.isGroup && chat.groupStatus != 0) {
            [realmManager updateObject:chat realm:realm withBlock:^(OCTChat *theChat) {
                theChat.groupStatus = 0;
            }];
        }
        
        uint64_t maxMsgId = 0;
        NSMutableArray <OCTMessageAbstract *> *messages = @[].mutableCopy;
        for (GroupRealMsg *message in model.msgArray) {
            maxMsgId = MAX(message.msgId, maxMsgId);
            
            NSString *publicKey = [[[NSString alloc] initWithData:message.frPk encoding:NSUTF8StringEncoding] uppercaseString];
            
            // file
            if (message.msgType == MESSAGE_TYPE_GROUP_FILE_MESSAGE) {
                // skip messages sent by myself
                if ([publicKey isEqualToString:self.dataSource.managerGetTox.publicKey]) {
                    continue;
                }
                if ([realmManager checkMessageIsExisted:message.msgId chat:chat checkFile:YES realm:realm]) {
                    continue;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self.dataSource managerGetNotificationCenter] postNotificationName:kOCTBotFileMessageReceivedNotification object:message];
                });
                continue;
            }
            
            // deduplication
            if ([realmManager checkMessageIsExisted:message.msgId chat:chat checkFile:NO realm:realm]) {
                continue;
            }
            if (message.msgType == MESSAGE_TYPE_GROUP_INVITE_NOTICE) {
                [self handleGroupInviteWithData:message.msg messageId:message.msgId chat:chat];
                continue;
            }
            if (message.msgType == MESSAGE_TYPE_GROUP_LEAVE_NOTICE) {
                [self handleLeaveNoticeWithData:message.msg messageId:message.msgId];
                continue;
            }
            if (message.msgType == MESSAGE_TYPE_GROUP_KICKOUT_NOTICE) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleKickoutNoticeWithData:message.msg messageId:message.msgId];
                });
                continue;
            }
            if (message.msgType == MESSAGE_TYPE_GROUP_DISSMISS_NOTICE) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleDissolveNoticeWithData:message.msg messageId:message.msgId];
                });
                continue;
            }
            
            if (message.msgType == MESSAGE_TYPE_GROUP_TEXT_MESSAGE) { // text
                // skip messages sent by myself
                if ([publicKey isEqualToString:self.dataSource.managerGetTox.publicKey]) {
                    continue;
                }
                
                NSString *text = [[NSString alloc] initWithData:message.msg encoding:NSUTF8StringEncoding];
                
                if (text == nil) {
                    continue;
                }
                
                NSTimeInterval time = message.createTime / 1000.0;
                NSString *nickname = [[NSString alloc] initWithData:message.frName encoding:NSUTF8StringEncoding];
                OCTPeer *peer = [realmManager peerWithPeerPK:publicKey groupNumber:chat.groupNumber realm:realm];
                if (peer == nil) {
                    peer = [OCTPeer new];
                    peer.publicKey = publicKey;
                    peer.groupNumber = groupNumber;
                    peer.nickname = nickname;

                    [realm beginWriteTransaction];
                    [realm addObject:peer];
                    [realm commitWriteTransaction];
                } else if (nickname.length > 0 && ![peer.nickname isEqualToString:nickname]) {
                    [realmManager updateObject:peer realm:realm withBlock:^(OCTPeer *thePeer) {
                        thePeer.nickname = nickname;
                    }];
                }
                
                OCTMessageAbstract *messageAbstract = [realmManager createMessageWithText:text type:OCTToxMessageTypeGroup chat:chat sender:peer messageId:message.msgId dateInterval:time status:1 realm:realm];
                
                [messages addObject:messageAbstract];
            }
        }
        
        [realm beginWriteTransaction];
        [realm addObjects:messages];
        [realm commitWriteTransaction];
        
        // Send delete cmd
        if (model.msgArray.count > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), self.groupMessageDispatchQueue, ^{
                GroupMessageDelReq *del = [GroupMessageDelReq new];
                del.groupId = groupNumber;
                del.lastMsgId = maxMsgId;
                OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                                        cmd:OCTToxGroupCmdMessageDel
                                                                                            botFriendNumber:botFriendNumber
                                                                                                  messageId:-1
                                                                                                    message:[del data]
                                                                                               successBlock:nil
                                                                                               failureBlock:nil];
                [self.sendMessageQueue addOperation:operation];
            });
        }
    });
}

- (void)handleGroupInfoWithData:(NSData *)messageData
{
    NSError *error;
    GroupInfoRes *model = [GroupInfoRes parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    NSString *title = [[NSString alloc] initWithData:model.groupName encoding:NSUTF8StringEncoding];
    NSString *ownerPk = [OCTTox binToHexString:model.ownerPk];
    NSString *desc = [[NSString alloc] initWithData:model.remark encoding:NSUTF8StringEncoding];
    NSInteger count = model.membersNum;
    NSString *shareId = [[NSString alloc] initWithData:model.shareId encoding:NSUTF8StringEncoding];
    NSInteger type = model.type;
    BOOL muted = model.status == 1;
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
    if (chat != nil && title != nil && ownerPk != nil) {
        [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
            theChat.title = title;
            theChat.ownerPublicKey = ownerPk;
            theChat.groupDescription = desc;
            theChat.groupMemebersCount = count;
            theChat.groupId = shareId;
            theChat.groupType = type;
            theChat.isMute = muted;
        }];
    }
    
    NSDictionary *userInfo = @{@"title": title, @"desc": desc, @"count": @(count), @"shareId": shareId, @"groupType": @(type)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kOCTGroupInfoReceivedNotification object:nil userInfo:userInfo];
}

- (void)handleGroupPeersWithData:(NSData *)messageData
{
    NSError *error;
    GroupPeerListNewRes *model = [GroupPeerListNewRes parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
    if (chat == nil) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kOCTGroupPeerListReceivedNotification object:model];
}

- (void)handleGroupRecommendWithData:(NSData *)messageData
{
    NSError *error;
    GroupRecommendResponse *model = [GroupRecommendResponse parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kOCTGroupRecommendListReceivedNotification object:model];
}

- (void)handleMessageReadNoticeWithTox:(OCTTox *)tox botFriendNumber:(OCTToxFriendNumber)botFriendNumber data:(NSData *)messageData
{
    NSError *error;
    GroupMessageReadNotice *model = [GroupMessageReadNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    [model.msgsReadArray enumerateObjectsUsingBlock:^(GroupMessageRead * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self sendGroupPullRequestWithTox:tox botFriendNumber:botFriendNumber groupNumber:obj.groupId];
    }];
}

- (void)handleSetGroupTitleNoticeWithData:(NSData *)messageData
                                messageId:(OCTToxMessageId)messageId
{
    NSError *error;
    GroupSetTitleNotice *model = [GroupSetTitleNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
    if (chat == nil) {
        return;
    }
    
    NSString *title = [[NSString alloc] initWithData:model.groupName encoding:NSUTF8StringEncoding];
    if (title == nil) {
        return;
    }
    
    [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
        theChat.title = title;
    }];
    
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The group name was changed to %@", nil), title];
    [realmManager addOtherMessageWithText:message type:OCTToxMessageTypeGroup chat:chat messageType:1 messageId:messageId];
}

- (void)handleLeaveNoticeWithData:(NSData *)messageData
                        messageId:(OCTToxMessageId)messageId
{
    NSError *error;
    GroupLeaveNotice *model = [GroupLeaveNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    RLMRealm *realm = [realmManager database];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId realm:realm];
    if (chat == nil) {
        return;
    }
    
    NSString *peerName = [[NSString alloc] initWithData:model.peerName encoding:NSUTF8StringEncoding];
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@ left", nil), peerName];
    [realmManager addOtherMessageWithText:message type:OCTToxMessageTypeGroup chat:chat messageType:1 messageId:messageId realm:realm];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self getGroupInfoWithGroupNumber:model.groupId];
    });
}

- (void)handleKickoutNoticeWithData:(NSData *)messageData
                          messageId:(OCTToxMessageId)messageId
{
    NSError *error;
    GroupKickoutNotice *model = [GroupKickoutNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
    if (chat == nil) {
        return;
    }
    
    NSString *kickoutPk = [[NSString alloc] initWithData:model.peerPk encoding:NSUTF8StringEncoding];
    
    NSString *message;
    if ([kickoutPk isEqualToString:self.dataSource.managerGetTox.publicKey]) {
        [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
            theChat.groupStatus = 1;
        }];
        
        message = NSLocalizedString(@"You were removed from this group", nil);
    } else {
        NSString *peerName = [[NSString alloc] initWithData:model.peerName encoding:NSUTF8StringEncoding];
        message = [NSString stringWithFormat:NSLocalizedString(@"%@ was removed from this group", nil), peerName];
    }
    [realmManager addOtherMessageWithText:message type:OCTToxMessageTypeGroup chat:chat messageType:1 messageId:messageId];
}

- (void)handleDissolveNoticeWithData:(NSData *)messageData
                           messageId:(OCTToxMessageId)messageId
{
    NSError *error;
    GroupDismissNotice *model = [GroupDismissNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
    if (chat == nil) {
        return;
    }
    
    [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
        theChat.groupStatus = 2;
    }];
    [realmManager addOtherMessageWithText:NSLocalizedString(@"Group was dissolved", nil)
                                     type:OCTToxMessageTypeGroup
                                     chat:chat
                              messageType:1
                                messageId:messageId];
}

- (void)handleErrorNoticeWithData:(NSData *)messageData
                        messageId:(OCTToxMessageId)messageId
{
    NSError *error;
    GroupErrorNotice *model = [GroupErrorNotice parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getGroupChatWithGroupNumber:model.groupId];
    if (chat == nil) {
        return;
    }
    if (chat.groupStatus == 1) {
        return;
    }
    // /** 1: not group member; 2: not group owner; 3: group is not exist; 4: is group member already */
    if (model.code == 1) {
        [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
            theChat.groupStatus = 1;
        }];
        [realmManager addOtherMessageWithText:NSLocalizedString(@"You were removed from this group", nil)
                                         type:OCTToxMessageTypeGroup
                                         chat:chat
                                  messageType:1
                                    messageId:messageId];
    } else if (model.code == 3) {
        [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
            theChat.groupStatus = 1;
        }];
        [realmManager addOtherMessageWithText:NSLocalizedString(@"Group was dissolved", nil)
                                         type:OCTToxMessageTypeGroup
                                         chat:chat
                                  messageType:1
                                    messageId:messageId];
    }
}

- (void)handleGroupJoinRequestWithData:(NSData *)messageData
{
    NSError *error;
    GroupAcceptJoinRequest *message = [GroupAcceptJoinRequest parseFromData:messageData error:&error];
    if (error) {
        return;
    }
    NSString *nobody = [[NSUserDefaults standardUserDefaults] stringForKey:@"user-info/join-group-setting"];
    for (GroupAcceptJoinInfo *model in message.infoArray) {
        if ([nobody isEqualToString:@"nobody"]) {
            [self sendAcceptJoinResponseWithGroupNumber:model.groupId result:1]; // refuse
            return;
        }
        
        OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
        NSString *inviterPk = [[NSString alloc] initWithData:model.inviterPk encoding:NSUTF8StringEncoding];
        OCTFriend *friend = [realmManager friendWithPublicKey:inviterPk friendState:0];
        
        /** 0 is agree, 1 is refuse */
        NSInteger result = friend == nil ? 1 : 0;
        [self sendAcceptJoinResponseWithGroupNumber:model.groupId result:result];
        if (friend == nil) {
            return;
        }
        
        OCTChat *chat = [realmManager getOrCreateChatWithGroupNumber:model.groupId];
        NSString *title = [[NSString alloc] initWithData:model.groupTitle encoding:NSUTF8StringEncoding];
        NSString *remark = [[NSString alloc] initWithData:model.groupRemark encoding:NSUTF8StringEncoding];
        
        [realmManager updateObject:chat withBlock:^(OCTChat *theChat) {
            theChat.title = title;
            theChat.groupDescription = remark;
        }];
    }
}

- (void)sendGroupPullRequestWithTox:(OCTTox *)tox botFriendNumber:(OCTToxFriendNumber)botFriendNumber groupNumber:(NSInteger)groupNumber
{
    GroupMessagePullReq *pull = [GroupMessagePullReq new];
    pull.groupId = groupNumber;
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdMessagePull
                                                                                botFriendNumber:botFriendNumber
                                                                                      messageId:-1
                                                                                        message:[pull data]
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    [self.sendMessageQueue addOperation:operation];
}

- (void)sendAcceptJoinResponseWithGroupNumber:(NSInteger)groupNumber
                                 result:(NSInteger)result
{
    GroupAcceptJoinResponse *model = [GroupAcceptJoinResponse new];
    model.groupId = groupNumber;
    model.result = (uint32_t)result;
    
    OCTTox *tox = self.dataSource.managerGetTox;
    OCTToxFriendNumber botFriendNumber = [self groupBot].friendNumber;
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdAcceptJoinResponse
                                                                                botFriendNumber:botFriendNumber
                                                                                      messageId:-1
                                                                                        message:[model data]
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    [self.sendMessageQueue addOperation:operation];
}

#pragma mark - Group Delegate

- (void)tox:(OCTTox *)tox friendNumber:(OCTToxFriendNumber)friendNumber groupCmd:(OCTToxGroupCmd)groupCmd messageData:(NSData *)messageData length:(NSInteger)length
{
    switch (groupCmd) {
        case OCTToxGroupCmdCreateResponse: {
            [self handleGroupCreateWithData:messageData];
            break;
        }
        case OCTToxGroupCmdPeerListResponse: {
            [self handleGroupPeersWithData:messageData];
            break;
        }
        case OCTToxGroupCmdInfoResponse: {
            [self handleGroupInfoWithData:messageData];
            break;
        }
        case OCTToxGroupCmdGetTitleResponse: {
            break;
        }
        case OCTToxGroupCmdMessagePullResponse: {
            [self handleGroupMessageWithTox:tox botFriendNumber:friendNumber data:messageData];
            break;
        }
        case OCTToxGroupCmdMessageReadNotice: {
            [self handleMessageReadNoticeWithTox:tox botFriendNumber:friendNumber data:messageData];
            break;
        }
        case OCTToxGroupCmdSetTitleNotice: {
            [self handleSetGroupTitleNoticeWithData:messageData messageId:-1];
            break;
        }
        case OCTToxGroupCmdInviteNotice: {
//            [self handleGroupInviteWithData:messageData messageId:-1];
            break;
        }
        case OCTToxGroupCmdLeaveNotice: {
            [self handleLeaveNoticeWithData:messageData messageId:-1];
            break;
        }
        case OCTToxGroupCmdKickoutNotice: {
            [self handleKickoutNoticeWithData:messageData messageId:-1];
            break;
        }
        case OCTToxGroupCmdDissolveNotice: {
            [self handleDissolveNoticeWithData:messageData messageId:-1];
            break;
        }
        case OCTToxGroupCmdErrorNotice: {
            [self handleErrorNoticeWithData:messageData messageId:-1];
            break;
        }
        case OCTToxGroupCmdAcceptJoinRequest: {
            [self handleGroupJoinRequestWithData:messageData];
            break;
        }
        case OCTToxGroupCmdRecommendResponse: {
            [self handleGroupRecommendWithData:messageData];
            break;
        }
        default:
            break;
    }
}

#pragma mark - Group Methods

- (void)sendGroupMessageToChat:(OCTChat *)chat
                          text:(NSString *)text
                  successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
                  failureBlock:(void (^)(NSError *error))userFailureBlock
{
    NSParameterAssert(chat);
    NSParameterAssert(text);
    
    OCTFriend *bot = [self groupBot];
    if (bot == nil) {
        return;
    }
    if (chat.groupStatus != 0) {
        return;
    }
    
    OCTToxMessageType type = OCTToxMessageTypeGroup;
    
    OCTToxFriendNumber botFriendNumber = bot.friendNumber;
    
    NSArray<NSString *> *splitTexts = [self splitMessage:text maxLength:kOCTToxMaxOfflineMessageLength / 4.0];
    for (NSString *splitText in splitTexts) {
        __weak OCTSubmanagerChatsImpl *weakSelf = self;
        OCTSendGroupMessageOperationSuccessBlock successBlock = ^(OCTToxMessageId messageId) {
            __strong OCTSubmanagerChatsImpl *strongSelf = weakSelf;
            
            OCTRealmManager *realmManager = [strongSelf.dataSource managerGetRealmManager];
            OCTMessageAbstract *message = [realmManager addMessageWithText:splitText type:type chat:chat sender:nil messageId:messageId dateInterval:0 status:messageId < 0 ? 2 : 0 withoutNotifying:nil];
            
            if (userSuccessBlock) {
                userSuccessBlock(message);
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (chat.isInvalidated) {
                    return;
                }
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld",
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
        
        OCTSendGroupMessageOperationFailureBlock failureBlock = ^(NSError *error) {
            successBlock(-1);
        };
        
        OCTTox *tox = [self.dataSource managerGetTox];
        OCTToxMessageId messageId = [tox generateMessageId];

        GroupMessageReq *model = [GroupMessageReq new];
        model.groupId = chat.groupNumber;
        model.msg = [splitText dataUsingEncoding:NSUTF8StringEncoding];
        model.frPk = [tox.publicKey dataUsingEncoding:NSUTF8StringEncoding];
        model.localMsgId = messageId;
        NSData *messageData = [model data];
        
        OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                                cmd:OCTToxGroupCmdMessage
                                                                                    botFriendNumber:botFriendNumber
                                                                                          messageId:messageId
                                                                                            message:messageData
                                                                                       successBlock:successBlock
                                                                                       failureBlock:failureBlock];
        
        [self.sendMessageQueue addOperation:operation];
    }
}

- (void)createGroupWithName:(NSString *)name
                  groupType:(NSInteger)groupType
               successBlock:(OCTGroupMessageSuccessBlock)successBlock
               failureBlock:(OCTGroupMessageFailureBlock)failureBlock
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        if (failureBlock) {
            failureBlock(nil);
        }
        return;
    }
    
    _createSuccessBlock = [successBlock copy];
    _createFailureBlock = [failureBlock copy];
    
    GroupCreateReq *model = [GroupCreateReq new];
    model.groupName = [name dataUsingEncoding:NSUTF8StringEncoding];
    model.type = (uint32_t)groupType;
    
    NSData *messageData = [model data];
    
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdCreate
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:^(NSError * _Nonnull error) {
                                                                                       if (failureBlock) {
                                                                                           failureBlock(error);
                                                                                       }
                                                                                   }];
    
    [self.sendMessageQueue addOperation:operation];
}

- (void)inviteFriend:(OCTFriend *)friend toGroupChat:(OCTChat *)chat
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupInviteReq *model = [GroupInviteReq new];
    model.groupId = chat.groupNumber;
    model.inviterPk = [tox.publicKey dataUsingEncoding:NSUTF8StringEncoding];
    model.inviteePk = [friend.publicKey dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdInvite
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (void)joinPublicGroup:(NSString *)groupShareId
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    BOOL valid = [tox shareIdIsValid:groupShareId];
    if (!valid) {
        return;
    }
    
    NSInteger idLength = [groupShareId substringWithRange:NSMakeRange(18, 1)].integerValue;
    NSInteger groupNumber = [groupShareId substringWithRange:NSMakeRange(18 - idLength, idLength)].integerValue;
    GroupInviteReq *model = [GroupInviteReq new];
    model.groupId = groupNumber;
    model.inviteePk = [tox.publicKey dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdInvite
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (void)kickoutPeer:(NSString *)publicKey fromGroupChat:(OCTChat *)chat
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupKickoutReq *model = [GroupKickoutReq new];
    model.groupId = chat.groupNumber;
    model.peerPk = [publicKey dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdKickout
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (void)getPeerListWithGroupNumber:(NSInteger)groupNumber page:(NSUInteger)page
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupPeerListNewReq *model = [GroupPeerListNewReq new];
    model.groupId = groupNumber;
    model.page = (uint32_t)page;
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdPeerList
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (BOOL)setGroupTitleWithGroupNumber:(NSInteger)groupNumber title:(NSString *)title
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return NO;
    }
    
    if (title == nil || [title isEqualToString:@""]) {
        return NO;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupSetTitleReq *model = [GroupSetTitleReq new];
    model.groupId = groupNumber;
    model.groupName = [title dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *messageData = [model data];
    
    __weak OCTSubmanagerChatsImpl *weakSelf = self;
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdSetTitle
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:^(OCTToxMessageId messageId) {
                                                                                       __strong OCTSubmanagerChatsImpl *strongSelf = weakSelf;
                                                                                       OCTChat *chat = [strongSelf.dataSource.managerGetRealmManager getGroupChatWithGroupNumber:groupNumber];
                                                                                       [strongSelf.dataSource.managerGetRealmManager
                                                                                        updateObject:chat withBlock:^(OCTChat *theObject) {
                                                                                            theObject.title = title;
                                                                                        }];
                                                                                   }
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
    
    return YES;
}

- (void)getGroupInfoWithGroupNumber:(NSInteger)groupNumber
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupInfoReq *model = [GroupInfoReq new];
    model.groupId = groupNumber;
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdInfo
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (void)getGroupTitleWithGroupNumber:(NSInteger)groupNumber
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupTitleReq *model = [GroupTitleReq new];
    model.groupId = groupNumber;
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdGetTitle
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (BOOL)leaveGroupWithGroupNumber:(NSInteger)groupNumber
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return NO;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTChat *chat = [realmManager getOrCreateChatWithGroupNumber:groupNumber];
    
    if ([chat.ownerPublicKey isEqualToString:self.dataSource.managerGetTox.publicKey]) {
        GroupDismissReq *model = [GroupDismissReq new];
        model.groupId = groupNumber;
        
        NSData *messageData = [model data];
        OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                                cmd:OCTToxGroupCmdDissolve
                                                                                    botFriendNumber:bot.friendNumber
                                                                                          messageId:-1
                                                                                            message:messageData
                                                                                       successBlock:nil
                                                                                       failureBlock:nil];
        
        [self.sendMessageQueue addOperation:operation];
    } else {
        GroupLeaveReq *model = [GroupLeaveReq new];
        model.groupId = groupNumber;
        
        NSData *messageData = [model data];
        OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                                cmd:OCTToxGroupCmdLeave
                                                                                    botFriendNumber:bot.friendNumber
                                                                                          messageId:-1
                                                                                            message:messageData
                                                                                       successBlock:nil
                                                                                       failureBlock:nil];
        
        [self.sendMessageQueue addOperation:operation];
    }
    
    return YES;
}

- (void)setMuteGroupWithGroupNumber:(NSInteger)groupNumber isMute:(BOOL)isMute
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupMuteReq *model = [GroupMuteReq new];
    model.groupId = groupNumber;
    model.status = isMute ? 1 : 0;
    
    NSData *messageData = [model data];
    OCTSendGroupMessageOperation *operation = [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                                                            cmd:OCTToxGroupCmdSetMute
                                                                                botFriendNumber:bot.friendNumber
                                                                                      messageId:-1
                                                                                        message:messageData
                                                                                   successBlock:nil
                                                                                   failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

- (void)setGroupRemarkWithGroupNumber:(NSInteger)groupNumber remark:(NSString *)remark
{
    OCTFriend *bot = [self groupBot];
    if (bot == nil || bot.isConnected == NO) {
        return;
    }
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    GroupRemarkReq *model = [GroupRemarkReq new];
    model.groupId = groupNumber;
    model.remark = [remark dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *messageData = [model data];
    __weak OCTSubmanagerChatsImpl *weakSelf = self;
    OCTSendGroupMessageOperation *operation =
    [[OCTSendGroupMessageOperation alloc] initWithTox:tox
                                                  cmd:OCTToxGroupCmdSetRemark
                                      botFriendNumber:bot.friendNumber
                                            messageId:-1
                                              message:messageData
                                         successBlock:^(OCTToxMessageId messageId) {
                                             __strong OCTSubmanagerChatsImpl *strongSelf = weakSelf;
                                             OCTChat *chat = [strongSelf.dataSource.managerGetRealmManager getGroupChatWithGroupNumber:groupNumber];
                                             [strongSelf.dataSource.managerGetRealmManager
                                              updateObject:chat withBlock:^(OCTChat *theObject) {
                                                 theObject.groupDescription = remark;
                                             }];
                                         } failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

#pragma mark - Stranger Public

- (void)sendStrangerCommandMessage:(NSString *)message
{
    OCTFriend *bot = [self findFriendBot];
    if (bot == nil) {
        return;
    }
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTSendMessageOperation *operation = [[OCTSendMessageOperation alloc] initWithTox:tox
                                                                         friendNumber:bot.friendNumber
                                                                          messageType:OCTToxMessageTypeNormal
                                                                              message:message
                                                                         successBlock:nil
                                                                         failureBlock:nil];
    [self.sendMessageQueue addOperation:operation];
}

- (void)sendStrangerMessage:(NSData *)messageData command:(OCTToxStrangerCmd)cmd botFriendNumber:(OCTToxFriendNumber)botFriendNumber
{
    OCTTox *tox = [self.dataSource managerGetTox];
    OCTSendStrangerMessageOperation *operation = [[OCTSendStrangerMessageOperation alloc] initWithTox:tox
                                                                                                  cmd:cmd
                                                                                      botFriendNumber:botFriendNumber
                                                                                              message:messageData
                                                                                         successBlock:nil
                                                                                         failureBlock:nil];
    
    [self.sendMessageQueue addOperation:operation];
}

#pragma mark - Stranger Private

- (OCTFriend *)findFriendBot
{
    NSString *botPublicKey = [self.dataSource getStrangerMessageBotPublicKey];
    if (botPublicKey == nil) {
        return nil;
    }
    
    OCTFriend *bot = [[self.dataSource managerGetRealmManager] friendWithPublicKey:botPublicKey];
    return bot;
}

- (void)handleFindStrangerMessage:(NSData *)data
{
    
}

#pragma mark - Stranger Delegate

- (void)tox:(OCTTox *)tox friendNumber:(OCTToxFriendNumber)friendNumber strangerCmd:(OCTToxStrangerCmd)strangerCmd messageData:(NSData *)messageData length:(NSInteger)length
{
    switch (strangerCmd) {
        case OCTToxStrangerCmdGetListResponse:
            [[NSNotificationCenter defaultCenter] postNotificationName:kOCTStrangerMessageReceivedNotification object:messageData];
            break;
        case OCTToxStrangerCmdSignatureResponse:
            [[NSNotificationCenter defaultCenter] postNotificationName:kOCTStrangerSignatureReceivedNotification object:messageData];
            break;
        default:
            break;
    }
}

@end
