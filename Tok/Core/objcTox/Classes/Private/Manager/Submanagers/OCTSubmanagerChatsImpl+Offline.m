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

#pragma mark - Private

- (void)handleOfflineMessageQueryResponseWithTox:(OCTTox *)tox data:(NSData *)data botFriendNumber:(OCTToxFriendNumber)botFriendNumber
{
    QueryFriendRes *model = [QueryFriendRes parseFromData:data error:nil];
    if (model == nil) {
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
//    NSError *error;
//    OfflineMessageRes *model = [OfflineMessageRes parseFromData:data error:&error];
//    if (error || model == nil) {
//        NSLog(@"OfflineMessageSendResponse Parse error");
//        return;
//    }
//    
//    OCTToxMessageId messageId = model.localMsgId;
//    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"messageText.messageId == %lld", messageId];
//    
//    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
//    OCTMessageAbstract *message = [results firstObject];
//    
//    if (! message) {
//        return;
//    }
//    
//    NSLog(@"Offline Message Send Response. messageId: %llu", messageId);
//    [realmManager updateObject:message withBlock:^(OCTMessageAbstract *theMessage) {
//        theMessage.messageText.status = 1;
//    }];
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
    NSError *error;
    OfflineMessagePullRes *model = [OfflineMessagePullRes parseFromData:data error:&error];
    if (error || model == nil) {
        return;
    }
    
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];

    uint64_t maxMsgId = 0;
    for (OfflineMessage *message in model.msgArray) {
        maxMsgId = MAX(message.msgId, maxMsgId);
        
        OCTToxMessageId messageId = message.localMsgId;
        NSTimeInterval time = message.createTime / 1000.0;
        NSString *publicKey = [[NSString alloc] initWithData:message.frPk encoding:NSUTF8StringEncoding];
        
        if (message.msgType == 2) { // new friend request
            OCTFriend *friend = [self.dataSource.managerGetRealmManager friendWithPublicKey:publicKey friendState:0];
            if (friend) { // the friend was added, send to accept request automatically
                [self sendOfflineFriendAcceptRequestWithPublicKey:publicKey];
            } else {
                NSString *info = [[NSString alloc] initWithData:message.content encoding:NSUTF8StringEncoding];
                [self.dataSource.managerGetRealmManager addFriendRequestWithMessage:info publicKey:publicKey isOutgoing:NO];
            }
            continue;
        }
        if (message.msgType == 3) { // friend accept request
            [self.dataSource.managerGetRealmManager friendAcceptRequest:publicKey];
            continue;
        }
        
        OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
        if (friend == nil) {
            continue;
        }
        OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
        if (message.msgType == 1) { // file
            if ([realmManager checkMessageIsExisted:message.msgId chat:chat checkFile:YES]) {
                continue;
            }
            [[self.dataSource managerGetNotificationCenter] postNotificationName:kOCTBotFileMessageReceivedNotification object:message];
        } else if (message.msgType == 0) {
            if ([realmManager checkMessageIsExisted:messageId chat:chat checkFile:NO]) {
                continue;
            }
            
            // Add offline message
            NSData *data = [tox decryptOfflineMessage:message.content friendNumber:friend.friendNumber];
            if (data == nil) {
                continue;
            }
            NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            OCTLogDebug(@"receive offline msg: %@", msg);
            if (msg != nil || [msg isEqualToString:@""]) {
                [realmManager addMessageWithText:msg type:OCTToxMessageTypeOffline chat:chat sender:friend messageId:messageId dateInterval:time status:1 withoutNotifying:nil];
            }
        }
    }
    
    OCTLogDebug(@"Offline Message Pull Response. message count: %ld, max msg id: %lld, left count: %ld", model.msgArray.count, maxMsgId, model.leftCount);
    
    // Send delete cmd
    if (model.msgArray.count > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            OfflineMessageDelReq *del = [OfflineMessageDelReq new];
            del.lastMsgId = maxMsgId;
            OCTSendOfflineMessageOperation *operation = [[OCTSendOfflineMessageOperation alloc] initOfflineWithTox:tox
                                                                                                               cmd:OCTToxMessageOfflineCmdDelRequest
                                                                                                   botFriendNumber:botFriendNumber
                                                                                                           message:[del data]];
            [self.sendMessageQueue addOperation:operation];
        });
    }
}

@end
