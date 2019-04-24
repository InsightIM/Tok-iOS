//
//  OCTSubmanagerChatsImpl+Offline.m
//  Tok
//
//  Created by Bryce on 2019/4/23.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "OCTSubmanagerChatsImpl+Offline.h"
#import "OCTSubmanagerDataSource.h"
#import "OCTSubmanagerChats.h"
#import "Message.pbobjc.h"
#import "OCTLogging.h"
#import "OCTTox.h"
#import "OCTRealmManager.h"
#import "OCTFriend.h"
#import "OCTChat.h"
#import "OCTMessageAbstract.h"
#import "OCTMessageText.h"
#import "OCTSendOfflineMessageOperation.h"

@implementation OCTSubmanagerChatsImpl (Offline)

#pragma mark - Delegate

- (void)tox:(OCTTox *)tox friendNumber:(OCTToxFriendNumber)friendNumber offlineCmd:(OCTToxMessageOfflineCmd)offlineCmd messageData:(NSData *)messageData length:(NSInteger)length
{
    switch (offlineCmd) {
        case OCTToxMessageOfflineCmdQueryResponse:
            [self handleOfflineMessageQueryResponseWithTox:tox data:messageData botFriendNumber:friendNumber];
            break;
        case OCTToxMessageOfflineCmdReadNotice:
            [self sendPullRequestWithTox:tox botFriendNumber:friendNumber];
            break;
        case OCTToxMessageOfflineCmdPullResponse:
            [self handlePullResponseWithTox:tox data:messageData botFriendNumber:friendNumber];
            break;
        case OCTToxMessageOfflineCmdSendResponse:
            [self handleOfflineMessageSendResponseWithData:messageData];
            break;
        default:
            break;
    }
}

#pragma mark - Public

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (void)queryFriendIsSupportOfflineMessage:(OCTFriend *)friend
{
    NSString *botPublicKey = [self.dataSource getOfflineMessageBotPublicKey];
    if (botPublicKey == nil) {
        NSLog(@"queryFriendIsSupportOfflineMessage not set botPublicKey");
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

#pragma clang diagnostic pop

#pragma mark - Private

- (void)handleOfflineMessageQueryResponseWithTox:(OCTTox *)tox data:(NSData *)data botFriendNumber:(OCTToxFriendNumber)botFriendNumber
{
    QueryFriendRes *model = [QueryFriendRes parseFromData:data error:nil];
    if (model == nil) {
        NSLog(@"OfflineMessageQueryFriendResponse Parse error");
        return;
    }
    BOOL exist = model.exist == 1;
    NSString *publicKey = [[NSString alloc] initWithData:model.pk encoding:NSUTF8StringEncoding];
    if (publicKey == nil) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    if (friend.supportOfflineMessage != exist) {
        [realmManager updateObject:friend withBlock:^(OCTFriend *theObject) {
            theObject.supportOfflineMessage = exist;
        }];
    }
}

- (void)handleOfflineMessageSendResponseWithData:(NSData *)data
{
    OfflineMessageRes *model = [OfflineMessageRes parseFromData:data error:nil];
    if (model == nil) {
        NSLog(@"OfflineMessageSendResponse Parse error");
        return;
    }
    
    OCTToxMessageId messageId = model.localMsgId;
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"messageText.messageId == %lld", messageId];
    
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    OCTMessageAbstract *message = [results firstObject];
    
    if (! message) {
        return;
    }
    
    NSLog(@"Offline Message Send Response. messageId: %lld ", messageId);
    [realmManager updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
        theMessage.messageText.status = 1;
    }];
}

- (void)sendPullRequestWithTox:(OCTTox *)tox botFriendNumber:(OCTToxFriendNumber)botFriendNumber
{
    OfflineMessagePullReq *pull = [OfflineMessagePullReq new];
    OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:tox
                                                                                                       cmd:OCTToxMessageOfflineCmdPullRequest
                                                                                           botFriendNumber:botFriendNumber
                                                                                                   message:[pull data]];
    [self.sendMessageQueue addOperation:operation];
}

- (void)handlePullResponseWithTox:(OCTTox *)tox data:(NSData *)data botFriendNumber:(OCTToxFriendNumber)botFriendNumber
{
    OfflineMessagePullRes *model = [OfflineMessagePullRes parseFromData:data error:nil];
    if (model == nil) {
        NSLog(@"OfflineMessagePullResponse Parse error");
        return;
    }
    
    uint64_t maxMsgId = 0;
    for (OfflineMessage *message in model.msgArray) {
        maxMsgId = MAX(message.msgId, maxMsgId);
        
        OCTToxMessageId messageId = message.localMsgId;
        NSTimeInterval time = message.createTime / 1000.0;
        NSString *publicKey = [[NSString alloc] initWithData:message.frPk encoding:NSUTF8StringEncoding];
        
        OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
        OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
        OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
        if ([self checkMessageIsExisted:messageId chat:chat]) {
            continue;
        }
        
        // Add offline message
        NSData *data = [tox decryptOfflineMessage:message.content friendNumber:friend.friendNumber];
        NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (msg != nil) {
            [realmManager addMessageWithText:msg type:OCTToxMessageTypeOffline chat:chat sender:friend messageId:messageId dateInterval:time status:1];
        }
    }
    
    NSLog(@"Offline Message Pull Response. message count: %ld, max msg id: %lld, left count: %ld", model.msgArray.count, maxMsgId, model.leftCount);
    
    // Send delete cmd
    if (model.msgArray.count > 0) {
        OfflineMessageDelReq *del = [OfflineMessageDelReq new];
        del.lastMsgId = maxMsgId;
        OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:tox
                                                                                                           cmd:OCTToxMessageOfflineCmdDelRequest
                                                                                               botFriendNumber:botFriendNumber
                                                                                                       message:[del data]];
        [self.sendMessageQueue addOperation:operation];
    }
    
    // There are more offline message, send pull cmd again
    BOOL needPullAgain = model.leftCount > 0;
    if (needPullAgain) {
        [self sendPullRequestWithTox:tox botFriendNumber:botFriendNumber];
    }
}

- (BOOL)checkMessageIsExisted:(OCTToxMessageId)messageId chat:(OCTChat *)chat
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld",
                              chat.uniqueIdentifier, messageId];
    
    // messageId is reset on every launch, so we want to update delivered status on latest message.
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    OCTMessageAbstract *message = [results firstObject];
    
    if (message) {
        return YES;
    }
    
    return NO;
}

@end
