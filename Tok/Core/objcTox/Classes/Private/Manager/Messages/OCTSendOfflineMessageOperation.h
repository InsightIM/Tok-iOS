//
//  OCTSendOfflineMessageOperation.h
//  Tok
//
//  Created by Bryce on 2019/4/23.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@class OCTTox;

NS_ASSUME_NONNULL_BEGIN

typedef void (^OCTSendOfflineMessageOperationSuccessBlock)(OCTToxMessageId messageId);
typedef void (^OCTSendOfflineMessageOperationFailureBlock)(NSError *error);

@interface OCTSendOfflineMessageOperation : NSOperation

- (instancetype)initOfflineWithTox:(OCTTox *)tox
                               cmd:(OCTToxMessageOfflineCmd)cmd
                         messageId:(OCTToxMessageId)messageId
                   botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                           message:(NSData *)message
                      successBlock:(nullable OCTSendOfflineMessageOperationSuccessBlock)successBlock
                      failureBlock:(nullable OCTSendOfflineMessageOperationFailureBlock)failureBlock;

- (instancetype)initOfflineWithTox:(OCTTox *)tox
                               cmd:(OCTToxMessageOfflineCmd)cmd
                   botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                           message:(NSData *)message;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
