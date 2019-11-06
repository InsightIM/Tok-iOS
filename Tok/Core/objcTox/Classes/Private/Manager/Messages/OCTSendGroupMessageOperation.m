//
//  OCTSendGroupMessageOperation.m
//  Tok
//
//  Created by Bryce on 2019/5/24.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "OCTSendGroupMessageOperation.h"
#import "OCTTox.h"
#import "Message.pbobjc.h"

@interface OCTSendGroupMessageOperation ()

@property (weak, nonatomic, readonly) OCTTox *tox;

@property (assign, nonatomic, readonly) OCTToxFriendNumber botFriendNumber;
@property (assign, nonatomic, readonly) OCTToxGroupCmd groupCmd;
@property (assign, nonatomic, readonly) OCTToxMessageId messageId;
@property (strong, nonatomic, readonly) NSData *message;
@property (copy, nonatomic, readonly) OCTSendGroupMessageOperationSuccessBlock successBlock;
@property (copy, nonatomic, readonly) OCTSendGroupMessageOperationFailureBlock failureBlock;

@end

@implementation OCTSendGroupMessageOperation

- (instancetype)initWithTox:(OCTTox *)tox
                        cmd:(OCTToxGroupCmd)cmd
            botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                  messageId:(OCTToxMessageId)messageId
                    message:(NSData *)message
               successBlock:(nullable OCTSendGroupMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendGroupMessageOperationFailureBlock)failureBlock
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _botFriendNumber = botFriendNumber;
    _groupCmd = cmd;
    _messageId = messageId;
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
    [self.tox sendGroupMessageWithBotFriendNumber:_botFriendNumber groupCmd:_groupCmd messageId:_messageId message:_message error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.cancelled) {
            return;
        }
        
        if (error && self.failureBlock) {
            self.failureBlock(error);
        }
        else if (! error && self.successBlock) {
            self.successBlock(self.messageId);
        }
    });
}

@end
