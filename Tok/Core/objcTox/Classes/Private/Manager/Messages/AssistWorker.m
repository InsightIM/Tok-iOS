//
//  AssistWorker.m
//  Tok
//
//  Created by Bryce on 2019/3/28.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "AssistWorker.h"
#import "OCTSendMessageOperation.h"
#import "OCTRealmManager.h"
#import "OCTTox.h"
#import "OCTFriend.h"
#import "OCTLogging.h"

static const NSTimeInterval kMaxRetryCount = 3;

@interface AssistWorker()

@property (nonatomic, strong) OCTTox *tox;
@property (nonatomic, strong) OCTRealmManager *realmManager;
@property (nonatomic, assign) OCTToxFriendNumber friendNumber;

@property (nonatomic, assign) NSUInteger times;
@property (nonatomic, strong) OCTSendMessageOperation *operation;
@property (nonatomic, copy) AssistWorkerCallbackBlock callbackBlock;

@end

@implementation AssistWorker

- (instancetype)initWithTox:(OCTTox *)tox
               realmManager:(OCTRealmManager *)realmManager
               friendNumber:(OCTToxFriendNumber)friendNumber
               completionBlock:(nullable AssistWorkerCallbackBlock)completionBlock
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _realmManager = realmManager;
    _friendNumber = friendNumber;
    _times = 0;
    _callbackBlock = completionBlock;
    
    return self;
}

#pragma mark - Public

- (void)start
{
    _operation = [[OCTSendMessageOperation alloc] initWithTox:_tox
                                                messageId:0
                                             friendNumber:_friendNumber
                                              messageType:OCTToxMessageTypeAssist
                                                  version:[OCTTox clientVersion]
                                             successBlock:nil
                                             failureBlock:nil];
    [self retry];
}

#pragma mark - Private

- (void)retry
{
    if (_times >= kMaxRetryCount) {
        if (_callbackBlock) {
            _callbackBlock(self);
        }
        return;
    }
    if ([self checkVersion]) {
        if (_callbackBlock) {
            _callbackBlock(self);
        }
        return;
    }
    _times += 1;
    
    NSLog(@"[Info] Send assist message, %d times. friendNumber: %d", _times, _friendNumber);
    
    [_operation start];
    
    __weak AssistWorker *weakSelf = self;
    NSTimer *timer = [NSTimer timerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf retry];
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (BOOL)checkVersion
{
    OCTRealmManager *realmManager = _realmManager;
    
    NSString *publicKey = [_tox publicKeyFromFriendNumber:_friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    
    return friend.clientVersion > 0;
}

@end
