//
//  OperationWorker.m
//  Tok
//
//  Created by Bryce on 2019/3/22.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "OperationWorker.h"
#import "OCTSendMessageOperation.h"
#import "OCTRealmManager.h"
#import "OCTTox.h"
#import "OCTChat.h"
#import "OCTFriend.h"
#import "OCTMessageAbstract.h"
#import "OCTMessageText.h"
#import "OCTLogging.h"

static const NSTimeInterval kMaxRetryCount = 4;

typedef NS_ENUM(NSUInteger, OWCheckState) {
    OWCheckStateFriendNotConnection,
    OWCheckStateMessageNotExist,
    OWCheckStateSuccess,
    OWCheckStateFailure,
    OWCheckStateWaiting,
};

#ifdef DEBUG
#define checkStateValueString(enum) [@[@"FriendNotConnection", @"MessageNotExist", @"Success", @"Failure", @"Waiting"] objectAtIndex:enum]
#endif

@interface OperationWorker()

@property (nonatomic, strong) OCTTox *tox;
@property (nonatomic, strong) OCTRealmManager *realmManager;
@property (nonatomic, assign) OCTToxFriendNumber friendNumber;
@property (nonatomic, assign) OCTToxMessageId messageId;
@property (nonatomic, assign) OCTToxMessageType messageType;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, assign) NSUInteger friendVersion;
@property (nonatomic, copy) OperationWorkerSuccessBlock successBlock;
@property (nonatomic, copy) OperationWorkerFailureBlock failureBlock;

@property (nonatomic, strong) OCTSendMessageOperation *operation;
@property (nonatomic, assign) BOOL isExecuting;
@property (strong, nonatomic, readonly) NSObject *lock;

@end

@implementation OperationWorker

- (instancetype)initWithTox:(OCTTox *)tox
               realmManager:(OCTRealmManager *)realmManager
                  messageId:(OCTToxMessageId)messageId
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
                       text:(nullable NSString *)text
              friendVersion:(NSUInteger)friendVersion
               successBlock:(nullable OperationWorkerSuccessBlock)successBlock
               failureBlock:(nullable OperationWorkerFailureBlock)failureBlock
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _realmManager = realmManager;
    _messageId = messageId;
    _friendNumber = friendNumber;
    _messageType = messageType;
    _text = text;
    _friendVersion = friendVersion;
    
    _isExecuting = NO;
    _lock = [NSObject new];
    
    _successBlock = [successBlock copy];
    _failureBlock = [failureBlock copy];
    
    return self;
}

#pragma mark - Public

- (void)start
{
    if (_isExecuting) {
        return;
    }
    @synchronized (self.lock) {
        self.isExecuting = YES;
    }
    
    _timeInterval = 2;
    
    _operation = [[OCTSendMessageOperation alloc] initWithTox:_tox
                                                    messageId:_messageId
                                                 friendNumber:_friendNumber
                                                  messageType:_messageType
                                                      message:_text
                                                      version:[self friendVersion]
                                                 successBlock:nil
                                                 failureBlock:nil];
    
    [self retry];
}

#pragma mark - Private

- (void)retry
{
    OWCheckState state = [self checkMessageStatus];
    switch (state) {
        case OWCheckStateFriendNotConnection:
        case OWCheckStateFailure:
        case OWCheckStateMessageNotExist:
            
            @synchronized (self.lock) {
                self.isExecuting = NO;
            }
            
            NSLog(@"[Error] Retry fauilre, status: %@, messageId: %lld, friendNumber: %d", checkStateValueString(state), _messageId, _friendNumber);
            
            if (_failureBlock) {
                _failureBlock(self, _messageId, _friendNumber);
            }
            return;
        case OWCheckStateSuccess:
            
            @synchronized (self.lock) {
                self.isExecuting = NO;
            }
            
            if (_successBlock) {
                _successBlock(self);
            }
            return;
        case OWCheckStateWaiting:
            break;
    }
    
    if (_messageType == OCTToxMessageTypeNormal) {
        if (_timeInterval > pow(2, kMaxRetryCount)) {
            
            @synchronized (self.lock) {
                self.isExecuting = NO;
            }
            
            NSLog(@"[Error] Retry timeout, messageId: %lld, friendNumber: %d", _messageId, _friendNumber);

            if (_failureBlock) {
                _failureBlock(self, _messageId, _friendNumber);
            }
            return;
        }
    }
    
    [_operation start];
    
    __weak OperationWorker *weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:_timeInterval repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf retry];
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
    _timeInterval *= 2;
}

- (OWCheckState)checkMessageStatus
{
    OCTRealmManager *realmManager = _realmManager;
    
    NSString *publicKey = [_tox publicKeyFromFriendNumber:_friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    OCTChat *chat = [realmManager getChatWithFriend:friend];
    
    if (chat == nil) {
        return OWCheckStateMessageNotExist;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatUniqueIdentifier == %@ AND messageText.messageId == %lld", chat.uniqueIdentifier, _messageId];
    
    // messageId is reset on every launch, so we want to update delivered status on latest message.
    RLMResults *results = [realmManager objectsWithClass:[OCTMessageAbstract class] predicate:predicate];
    results = [results sortedResultsUsingKeyPath:@"dateInterval" ascending:NO];
    
    OCTMessageAbstract *message = [results firstObject];
    
    if (! message) {
        return OWCheckStateMessageNotExist;
    }
    
    if (message.messageText.status == 1) {
        return OWCheckStateSuccess;
    }
    
    if (message.messageText.status == 2) {
        return OWCheckStateFailure;
    }
    
    if (friend.isConnected == NO) {
        return OWCheckStateFriendNotConnection;
    }
    
    return OWCheckStateWaiting;
}

@end
