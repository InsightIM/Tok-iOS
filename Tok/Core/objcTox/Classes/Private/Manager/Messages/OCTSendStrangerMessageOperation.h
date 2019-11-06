//
//  OCTSendStrangerMessageOperation.h
//  Tok
//
//  Created by Bryce on 2019/7/2.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@class OCTTox;


NS_ASSUME_NONNULL_BEGIN

typedef void (^OCTSendStrangerMessageOperationSuccessBlock)(OCTToxMessageId messageId);
typedef void (^OCTSendStrangerMessageOperationFailureBlock)(NSError *error);

@interface OCTSendStrangerMessageOperation : NSOperation

- (instancetype)initWithTox:(OCTTox *)tox
                        cmd:(OCTToxStrangerCmd)cmd
            botFriendNumber:(OCTToxFriendNumber)botFriendNumber
                    message:(NSData *)message
               successBlock:(nullable OCTSendStrangerMessageOperationSuccessBlock)successBlock
               failureBlock:(nullable OCTSendStrangerMessageOperationFailureBlock)failureBlock;

@end

NS_ASSUME_NONNULL_END
