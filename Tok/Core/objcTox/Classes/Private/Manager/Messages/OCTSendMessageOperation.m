// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSendMessageOperation.h"
#import "OCTTox.h"
#import "Message.pbobjc.h"

@interface OCTSendMessageOperation ()

@property (weak, nonatomic, readonly) OCTTox *tox;

@property (assign, nonatomic, readonly) OCTToxFriendNumber friendNumber;
@property (assign, nonatomic, readonly) OCTToxFriendNumber botFriendNumber;
@property (assign, nonatomic, readonly) OCTToxMessageType messageType;
@property (copy, nonatomic, readonly) NSString *message;
@property (assign, nonatomic, readonly) OCTToxMessageId messageId;
@property (assign, nonatomic, readonly) BOOL confirmStatus;
@property (assign, nonatomic, readonly) NSUInteger version;
@property (copy, nonatomic, readonly) OCTSendMessageOperationSuccessBlock successBlock;
@property (copy, nonatomic, readonly) OCTSendMessageOperationFailureBlock failureBlock;

@end

@implementation OCTSendMessageOperation

- (instancetype)initOfflineWithTox:(OCTTox *)tox
                         messageId:(OCTToxMessageId)messageId
                      friendNumber:(OCTToxFriendNumber)friendNumber
                   botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                           message:(NSString *)message
                      successBlock:(nullable OCTSendMessageOperationSuccessBlock)successBlock
                      failureBlock:(nullable OCTSendMessageOperationFailureBlock)failureBlock
{
    _botFriendNumber = botFriendNumber;
    return [self initWithTox:tox
                   messageId:messageId
                friendNumber:friendNumber
                 messageType:OCTToxMessageTypeOffline
                     message:message
               confirmStatus:NO
                     version:0
                successBlock:successBlock
                failureBlock:failureBlock];
}

- (instancetype)initWithTox:(OCTTox *)tox
                  messageId:(OCTToxMessageId)messageId
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
                    message:(NSString *)message
                    version:(NSUInteger)version
               successBlock:(nullable OCTSendMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendMessageOperationFailureBlock)failureBlock
{
    return [self initWithTox:tox
                   messageId:messageId
                friendNumber:friendNumber
                 messageType:messageType
                     message:message
               confirmStatus:NO
                     version:version
                successBlock:successBlock
                failureBlock:failureBlock];
}

- (instancetype)initWithTox:(OCTTox *)tox
                  messageId:(OCTToxMessageId)messageId
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
              confirmStatus:(BOOL)confirmStatus
                    version:(NSUInteger)version
               successBlock:(nullable OCTSendMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendMessageOperationFailureBlock)failureBlock
{
    return [self initWithTox:tox
                   messageId:messageId
                friendNumber:friendNumber
                 messageType:messageType
                     message:nil
               confirmStatus:confirmStatus
                     version:version
                successBlock:successBlock
                failureBlock:failureBlock];
}

- (instancetype)initWithTox:(OCTTox *)tox
                  messageId:(OCTToxMessageId)messageId
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
                    version:(NSUInteger)version
               successBlock:(nullable OCTSendMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendMessageOperationFailureBlock)failureBlock
{
    return [self initWithTox:tox
                   messageId:messageId
                friendNumber:friendNumber
                 messageType:messageType
                     message:nil
               confirmStatus:NO
                     version:version
                successBlock:successBlock
                failureBlock:failureBlock];
}

- (instancetype)initWithTox:(OCTTox *)tox
                  messageId:(OCTToxMessageId)messageId
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
                    message:(NSString *)message
              confirmStatus:(BOOL)confirmStatus
                    version:(NSUInteger)version
               successBlock:(nullable OCTSendMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendMessageOperationFailureBlock)failureBlock
{
    self = [super init];
    
    if (! self) {
        return nil;
    }
    
    _tox = tox;
    _messageId = messageId;
    _friendNumber = friendNumber;
    _confirmStatus = confirmStatus;
    _messageType = messageType;
    _message = [message copy];
    _version = version;
    _successBlock = [successBlock copy];
    _failureBlock = [failureBlock copy];
    
    return self;
}

- (void)main
{
    if (self.cancelled) {
        return;
    }
    
    OCTToxFriendNumber realFriendNumber = _friendNumber;
    NSData *messageData;
    switch (self.messageType) {
        case OCTToxMessageTypeEcho: {
            FriendMessageRes *model = [FriendMessageRes new];
            model.localMsgId = _messageId;
            
            messageData = [model data];
            break;
        }
        case OCTToxMessageTypeConfirm: {
            FriendMessageCfm *model = [FriendMessageCfm new];
            model.localMsgId = _messageId;
            model.sendStatus = _confirmStatus ? 1 : 0;
            
            messageData = [model data];
            break;
        }
        case OCTToxMessageTypeNormal: {
            FriendMessageReq *model = [FriendMessageReq new];
            model.localMsgId = _messageId;
            model.msg = [self.message dataUsingEncoding:NSUTF8StringEncoding];
            
            messageData = [model data];
            break;
        }
        case OCTToxMessageTypeOffline: {
            realFriendNumber = _botFriendNumber;
            NSData *cryptoMessage = [self.tox encryptOfflineMessage:_friendNumber message:_message];
            
            OfflineMessageReq *model = [OfflineMessageReq new];
            model.localMsgId = _messageId;
            model.toPk = [[self.tox publicKeyFromFriendNumber:_friendNumber error:nil] dataUsingEncoding:NSUTF8StringEncoding];
            model.cryptoMessage = cryptoMessage;
            
            messageData = [model data];
            break;
        }
        case OCTToxMessageTypeAction:
        case OCTToxMessageTypeForward:
        case OCTToxMessageTypeAssist:
        case OCTToxMessageTypeEnd:
        case OCTToxMessageTypeBot:
        case OCTToxMessageTypeGroup: {
            break;
        }
    }
    
    NSError *error;
    if (self.messageType == OCTToxMessageTypeOffline) {
        [self.tox sendOfflineMessageWithBotFriendNumber:realFriendNumber
                                              messageId:_messageId
                                                message:messageData
                                                  error:&error];
    } else if (_version == 0) {
        NSData *messageData = [self.message dataUsingEncoding:NSUTF8StringEncoding];
        _messageId = [self.tox sendMessageUsingOldVersionWithFriendNumber:realFriendNumber
                                                        type:_messageType
                                                     message:messageData
                                                       error:&error];
    } else {
        [self.tox sendMessageWithFriendNumber:realFriendNumber
                                         type:_messageType
                                    messageId:_messageId
                                      message:messageData
                                        error:&error];
    }
    
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
