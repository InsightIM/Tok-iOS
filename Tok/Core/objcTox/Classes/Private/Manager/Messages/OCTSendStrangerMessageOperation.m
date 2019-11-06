//
//  OCTSendStrangerMessageOperation.m
//  Tok
//
//  Created by Bryce on 2019/7/2.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "OCTSendStrangerMessageOperation.h"
#import "OCTTox.h"

@interface OCTSendStrangerMessageOperation ()

@property (weak, nonatomic, readonly) OCTTox *tox;

@property (assign, nonatomic, readonly) OCTToxFriendNumber botFriendNumber;
@property (assign, nonatomic, readonly) OCTToxStrangerCmd strangerCmd;
@property (strong, nonatomic, readonly) NSData *message;
@property (copy, nonatomic, readonly) OCTSendStrangerMessageOperationSuccessBlock successBlock;
@property (copy, nonatomic, readonly) OCTSendStrangerMessageOperationFailureBlock failureBlock;

@end

@implementation OCTSendStrangerMessageOperation

- (instancetype)initWithTox:(OCTTox *)tox
                        cmd:(OCTToxStrangerCmd)cmd
            botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                    message:(NSData *)message
               successBlock:(nullable OCTSendStrangerMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendStrangerMessageOperationFailureBlock)failureBlock
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _botFriendNumber = botFriendNumber;
    _strangerCmd = cmd;
    _message = message;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    
    return self;
}

- (void)main
{
    if (self.cancelled) {
        return;
    }
    
    NSError *error;
    OCTToxMessageId messageId = [self.tox generateMessageId];
    [self.tox sendStrangerMessageWithBotFriendNumber:_botFriendNumber strangerCmd:_strangerCmd messageId:messageId message:_message error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.cancelled) {
            return;
        }
        
        if (error && self.failureBlock) {
            self.failureBlock(error);
        }
        else if (! error && self.successBlock) {
            self.successBlock(messageId);
        }
    });
}

@end
