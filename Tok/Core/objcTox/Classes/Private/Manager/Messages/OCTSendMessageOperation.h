// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@class OCTTox;

NS_ASSUME_NONNULL_BEGIN

typedef void (^OCTSendMessageOperationSuccessBlock)(OCTToxMessageId messageId);
typedef void (^OCTSendMessageOperationFailureBlock)(NSError *error);

@interface OCTSendMessageOperation : NSOperation

/**
 * Create operation.
 *
 * @param tox Tox object to send to.
 * @param friendNumber Number of friend to send to.
 * @param messageType Type of the message to send.
 * @param message Message to send.
 * @param successBlock Block called on operation success. Block will be called on main thread.
 * @param failureBlock Block called on loading error. Block will be called on main thread.
 */
- (instancetype)initWithTox:(OCTTox *)tox
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
                    message:(NSString *)message
               successBlock:(nullable OCTSendMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendMessageOperationFailureBlock)failureBlock;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
