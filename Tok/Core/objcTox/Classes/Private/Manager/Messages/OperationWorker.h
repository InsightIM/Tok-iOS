//
//  OperationWorker.h
//  Tok
//
//  Created by Bryce on 2019/3/22.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"
@class OCTTox;
@class OCTRealmManager;
@class OperationWorker;

NS_ASSUME_NONNULL_BEGIN

typedef void (^OperationWorkerSuccessBlock)(OperationWorker *worker);
typedef void (^OperationWorkerFailureBlock)(OperationWorker *worker, OCTToxMessageId messageId, OCTToxFriendNumber friendNumber);

@interface OperationWorker : NSObject

@property (nonatomic, assign, readonly) OCTToxFriendNumber friendNumber;
@property (nonatomic, assign, readonly) OCTToxMessageId messageId;
@property (nonatomic, assign, readonly) BOOL isExecuting;

- (instancetype)initWithTox:(OCTTox *)tox
               realmManager:(OCTRealmManager *)realmManager
                  messageId:(OCTToxMessageId)messageId
               friendNumber:(OCTToxFriendNumber)friendNumber
                messageType:(OCTToxMessageType)messageType
                       text:(nullable NSString *)text
              friendVersion:(NSUInteger)friendVersion
               successBlock:(nullable OperationWorkerSuccessBlock)successBlock
               failureBlock:(nullable OperationWorkerFailureBlock)failureBlock;

- (void)start;

@end

NS_ASSUME_NONNULL_END
