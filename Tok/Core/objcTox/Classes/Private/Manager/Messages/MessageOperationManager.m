//
//  MessageManager.m
//  Tok
//
//  Created by Bryce on 2019/3/22.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "MessageOperationManager.h"
#import "OCTSendMessageOperation.h"
#import "OCTRealmManager.h"
#import "OCTTox.h"
#import "OCTChat.h"
#import "OCTFriend.h"
#import "OCTMessageAbstract.h"
#import "OCTMessageText.h"
#import "OperationWorker.h"
#import "Message.pbobjc.h"
#import "OCTLogging.h"
#import "AssistWorker.h"

@interface MessageOperationManager()

@property (strong) OCTTox *tox;
@property (strong) OCTRealmManager *realmManager;

@property (strong) NSMutableArray<OperationWorker *> *sendingQueue;
@property (strong) NSMutableArray<OperationWorker *> *responseQueue;
@property (strong) NSMutableArray<AssistWorker *> *assistQueue;

@property (strong, nonatomic, readonly) NSObject *sendingLock;
@property (strong, nonatomic, readonly) NSObject *responseLock;
@property (strong, nonatomic, readonly) NSObject *assistLock;

@property (strong) NSOperationQueue *confirmQueue;

@end

@implementation MessageOperationManager

- (instancetype)initWithTox:(OCTTox *)tox
               realmManager:(OCTRealmManager *)realmManager
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _realmManager = realmManager;
    
    _sendingQueue = @[].mutableCopy;
    _responseQueue = @[].mutableCopy;
    _assistQueue = @[].mutableCopy;
    
    _sendingLock = [NSObject new];
    _responseLock = [NSObject new];
    _assistLock = [NSObject new];
    
    _confirmQueue = [NSOperationQueue new];
    _confirmQueue.maxConcurrentOperationCount = 1;
    
    return self;
}

#pragma mark - Public

- (void)sendText:(NSString *)text toFriendNumber:(OCTToxFriendNumber)friendNumber inChat:(OCTChat *)chat messageType:(OCTToxMessageType)messageType
{
    OCTToxMessageId messageId = [self generateMessageId];
    [self addMessage:text messageId:messageId friendNumber:friendNumber time:0];

    NSLog(@"[1.1] Send Text Message. \nId: %lld, friendNumber: %d, text: %@", messageId, friendNumber, text);

    __weak MessageOperationManager *weakSelf = self;
    OperationWorkerSuccessBlock successBlock = ^(OperationWorker *worker) {
        [weakSelf removeWorker:worker from:weakSelf.sendingQueue lock:weakSelf.sendingLock];
    };
    
    OperationWorkerFailureBlock failureBlock = ^(OperationWorker *worker, OCTToxMessageId messageId, OCTToxFriendNumber friendNumber) {
        [weakSelf setMessageStatus:messageId friendNumber:friendNumber isSuccess:NO];
        [weakSelf sendConfirmMessage:worker.messageId friendNumber:worker.friendNumber success:NO];
        [weakSelf removeWorker:worker from:weakSelf.sendingQueue lock:weakSelf.sendingLock];
    };
    
    NSUInteger friendVersion = [self friendVersionWith:friendNumber];
    OperationWorker *worker = [[OperationWorker alloc] initWithTox:_tox
                                                      realmManager:_realmManager
                                                         messageId:messageId
                                                      friendNumber:friendNumber
                                                       messageType:messageType
                                                              text:text
                                                     friendVersion:friendVersion
                                                      successBlock:successBlock
                                                      failureBlock:failureBlock];
    
    [self addWoker:worker into:_sendingQueue lock:_sendingLock];
}

- (void)sendResponseMessage:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber message:(NSString *)message time:(NSTimeInterval)time
{
    for (OperationWorker *worker in _responseQueue) {
        if (worker.messageId == messageId && worker.friendNumber == friendNumber) {
            return;
        }
    }

    if ([self checkMessageExist:messageId friendNumber:friendNumber] == NO) {
        [self addReceivedMessage:message messageId:messageId friendNumber:friendNumber time:time];
    }
    
    __weak MessageOperationManager *weakSelf = self;
    OperationWorkerSuccessBlock successBlock = ^(OperationWorker *worker) {
        [weakSelf removeWorker:worker from:weakSelf.responseQueue lock:weakSelf.responseLock];
    };
    
    OperationWorkerFailureBlock failureBlock = ^(OperationWorker *worker, OCTToxMessageId messageId, OCTToxFriendNumber friendNumber) {
        [weakSelf removeWorker:worker from:weakSelf.responseQueue lock:weakSelf.responseLock];
    };
    
    NSUInteger friendVersion = [self friendVersionWith:friendNumber];
    OperationWorker *worker = [[OperationWorker alloc] initWithTox:_tox
                                                      realmManager:_realmManager
                                                         messageId:messageId
                                                      friendNumber:friendNumber
                                                       messageType:OCTToxMessageTypeEcho
                                                              text:nil
                                                     friendVersion:friendVersion
                                                      successBlock:successBlock
                                                      failureBlock:failureBlock];
    
    NSLog(@"[2.2] Send Echo Message. \nId: %lld, friendNumber: %d", messageId, friendNumber);
    
    [self addWoker:worker into:_responseQueue lock:_responseLock];
}

- (void)sendConfirmMessage:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber success:(BOOL)success
{
    OCTToxConnectionStatus status = [_tox friendConnectionStatusWithFriendNumber:friendNumber error:nil];
    if (status == OCTToxConnectionStatusNone) {
        NSLog(@"[Error] Send Confirm Message Failure, friend is offline. \nId: %lld, friendNumber: %d, result: %@", messageId, friendNumber, success ? @"Success" : @"Failure");
        return;
    }
    
    NSLog(@"[1.3] Send Confirm Message. \nId: %lld, friendNumber: %d, result: %@", messageId, friendNumber, success ? @"Success" : @"Failure");

    NSUInteger friendVersion = [self friendVersionWith:friendNumber];
    OCTSendMessageOperation *operation = [[OCTSendMessageOperation alloc] initWithTox:_tox
                                                                            messageId:messageId
                                                                         friendNumber:friendNumber
                                                                          messageType:OCTToxMessageTypeConfirm
                                                                        confirmStatus:success
                                                                              version:friendVersion
                                                                         successBlock:nil
                                                                         failureBlock:nil];
    
    [_confirmQueue addOperation:operation];
}

- (void)sendAssistMessageWithFriendNumber:(OCTToxFriendNumber)friendNumber
{
    for (AssistWorker *worker in _assistQueue) {
        if (worker.friendNumber == friendNumber) {
            return;
        }
    }
    
    __weak MessageOperationManager *weakSelf = self;
    AssistWorkerCallbackBlock completionBlock = ^(AssistWorker * _Nonnull worker) {
        @synchronized (weakSelf.assistLock) {
            [weakSelf.assistQueue removeObject:worker];
        }
    };
    
    AssistWorker *worker = [[AssistWorker alloc] initWithTox:_tox
                                                realmManager:_realmManager
                                                friendNumber:friendNumber
                                             completionBlock:completionBlock];
    
    @synchronized (self.assistLock) {
        [self.assistQueue addObject:worker];
    }
    [worker start];
}

- (void)resendUndeliveredMessagesToFriend:(OCTFriend *)friend
{
    if (friend == nil) {
        return;
    }
    
    OCTChat *chat = [_realmManager getChatWithFriend:friend];
    
    if (chat == nil) {
        return;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@"
                              @" AND senderUniqueIdentifier == %@"
                              @" AND messageText.status == 0",
                              friend.uniqueIdentifier,
                              chat.uniqueIdentifier];
    
    RLMResults *results = [_realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    
    for (OCTMessageAbstract *message in results) {
        [self sendResponseMessage:message.messageText.messageId
                     friendNumber:friend.friendNumber
                          message:message.messageText.text
                             time:message.dateInterval];
    }
    
#ifdef DEBUG
    if (results.count > 0) {
        NSLog(@"[Reconnection] Resend Echo Messages Count: %ld", results.count);
    }
#endif
    
}

- (void)setSendingMessageToFailed
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"senderUniqueIdentifier == nil AND messageText.status == 0"];
    
    [_realmManager updateObjectsWithClass:[OCTMessageAbstract class] predicate:predicate updateBlock:^(OCTMessageAbstract *theObject) {
        theObject.messageText.status = 2;
    }];
}

#pragma mark - Private

- (void)addWoker:(OperationWorker *)worker into:(NSMutableArray<OperationWorker *> *)queue lock:(NSObject *)lock
{
    @synchronized (lock) {
        [queue addObject:worker];
    }
    
    [self startNextFrom:queue];
}

- (void)removeWorker:(OperationWorker *)worker from:(NSMutableArray<OperationWorker *> *)queue lock:(NSObject *)lock
{
    @synchronized (lock) {
        [queue removeObject:worker];
    }
    
    [self startNextFrom:queue];
}

- (void)startNextFrom:(NSMutableArray<OperationWorker *> *)queue
{
    if (queue.count == 0) {
        return;
    }
    
#ifdef DEBUG
    if ([queue isEqual:_responseQueue]) {
        NSLog(@"[Info] Current echo queue count: %d", queue.count);
    } else {
        NSLog(@"[Info] Current sending queue count: %d", queue.count);
    }
#endif
    
    for (OperationWorker *worker in queue) {
        if (worker.isExecuting) {
            return;
        }
    }
    
    [queue.firstObject start];
}

- (void)addMessage:(NSString *)message messageId:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber time:(NSTimeInterval)time
{
    OCTRealmManager *realmManager = _realmManager;
    NSString *publicKey = [_tox publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
    
    [realmManager addMessageWithText:message type:OCTToxMessageTypeNormal chat:chat sender:nil messageId:(int64_t)messageId dateInterval:time status:0];
}

- (void)addReceivedMessage:(NSString *)message messageId:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber time:(NSTimeInterval)time
{
    OCTRealmManager *realmManager = _realmManager;
    NSString *publicKey = [_tox publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getOrCreateChatWithFriend:friend];
    
    [realmManager addMessageWithText:message type:OCTToxMessageTypeNormal chat:chat sender:friend messageId:(int64_t)messageId dateInterval:time status:0];
}

- (BOOL)checkMessageExist:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = self.realmManager;
    
    NSString *publicKey = [self.tox publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getChatWithFriend:friend];
    
    if (chat == nil) {
        return NO;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld", chat.uniqueIdentifier, messageId];
    
    // messageId is reset on every launch, so we want to update delivered status on latest message.
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    results = [results sortedResultsUsingKeyPath:@"dateInterval" ascending:NO];
    
    OCTMessageAbstract *message = [results firstObject];
    
    if (! message) {
        return NO;
    }
    
    return YES;
}

- (BOOL)setMessageStatus:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber isSuccess:(BOOL)isSuccess
{
    OCTRealmManager *realmManager = _realmManager;;
    
    NSString *publicKey = [_tox publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getChatWithFriend:friend];
    
    if (chat == nil) {
        return NO;
    }
    
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

- (OCTToxMessageId)generateMessageId {
    return [_tox generateMessageId];
}

- (NSUInteger)friendVersionWith:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = _realmManager;
    
    NSString *publicKey = [_tox publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    
    return friend.clientVersion;
}

@end
