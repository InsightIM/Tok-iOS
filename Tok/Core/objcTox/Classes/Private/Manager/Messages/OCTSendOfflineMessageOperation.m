//
//  OCTSendOfflineMessageOperation.m
//  Tok
//
//  Created by Bryce on 2019/4/23.
//  Copyright © 2019 Insight. All rights reserved.
//

#import "OCTSendOfflineMessageOperation.h"
#import "OCTTox.h"
#import "Message.pbobjc.h"

@interface OCTSendOfflineMessageOperation ()

@property (weak, nonatomic, readonly) OCTTox *tox;

@property (assign, nonatomic, readonly) OCTToxFriendNumber botFriendNumber;
@property (assign, nonatomic, readonly) OCTToxMessageOfflineCmd offlineCmd;
@property (assign, nonatomic, readonly) OCTToxMessageId messageId;
@property (strong, nonatomic, readonly) NSData *message;
@property (copy, nonatomic, readonly) OCTSendOfflineMessageOperationSuccessBlock successBlock;
@property (copy, nonatomic, readonly) OCTSendOfflineMessageOperationFailureBlock failureBlock;

@end

@implementation OCTSendOfflineMessageOperation

- (instancetype)initOfflineWithTox:(OCTTox *)tox
                               cmd:(OCTToxMessageOfflineCmd)cmd
                         messageId:(OCTToxMessageId)messageId
                   botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                           message:(NSData *)message
                      successBlock:(nullable OCTSendOfflineMessageOperationSuccessBlock)successBlock
                      failureBlock:(nullable OCTSendOfflineMessageOperationFailureBlock)failureBlock
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _botFriendNumber = botFriendNumber;
    _offlineCmd = cmd;
    _messageId = messageId;
    _message = message;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    
    return self;
}

- (instancetype)initOfflineWithTox:(OCTTox *)tox
                               cmd:(OCTToxMessageOfflineCmd)cmd
                   botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                           message:(NSData *)message
{
    return [self initOfflineWithTox:tox cmd:cmd messageId:0 botFriendNumber:botFriendNumber message:message successBlock:nil failureBlock:nil];
}

- (void)main
{
    if (self.cancelled) {
        return;
    }
    
    NSError *error;
    [self.tox sendOfflineMessageWithBotFriendNumber:_botFriendNumber offlineCmd:_offlineCmd messageId:_messageId message:_message error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.cancelled) {
            return;
        }
        
        if (error && self.failureBlock) {
            self.failureBlock(error);
        }
        else if (! error && self.successBlock && self.messageId > 0) {
            self.successBlock(self.messageId);
        }
    });
}

@end
