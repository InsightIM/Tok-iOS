//
//  OCTSendGroupMessageOperation.h
//  Tok
//
//  Created by Bryce on 2019/5/24.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@class OCTTox;

NS_ASSUME_NONNULL_BEGIN

typedef void (^OCTSendGroupMessageOperationSuccessBlock)(OCTToxMessageId messageId);
typedef void (^OCTSendGroupMessageOperationFailureBlock)(NSError *error);

@interface OCTSendGroupMessageOperation : NSOperation

- (instancetype)initWithTox:(OCTTox *)tox
                        cmd:(OCTToxGroupCmd)cmd
            botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                  messageId:(OCTToxMessageId)messageId
                    message:(NSData *)message
               successBlock:(nullable OCTSendGroupMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendGroupMessageOperationFailureBlock)failureBlock;

@end

NS_ASSUME_NONNULL_END
