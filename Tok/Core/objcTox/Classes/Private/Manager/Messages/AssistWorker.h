//
//  AssistWorker.h
//  Tok
//
//  Created by Bryce on 2019/3/28.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"
@class OCTTox;
@class OCTRealmManager;
@class AssistWorker;

NS_ASSUME_NONNULL_BEGIN

typedef void (^AssistWorkerCallbackBlock)(AssistWorker *worker);

@interface AssistWorker : NSObject

@property (nonatomic, assign, readonly) OCTToxFriendNumber friendNumber;

- (instancetype)initWithTox:(OCTTox *)tox
               realmManager:(OCTRealmManager *)realmManager
               friendNumber:(OCTToxFriendNumber)friendNumber
            completionBlock:(nullable AssistWorkerCallbackBlock)completionBlock;

- (void)start;

@end

NS_ASSUME_NONNULL_END
