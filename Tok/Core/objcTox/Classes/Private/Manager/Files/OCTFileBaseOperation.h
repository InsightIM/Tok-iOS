// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTTox.h"
#import "OCTToxConstants.h"

@class OCTFileBaseOperation;

/**
 * Block to notify about operation progress.
 *
 * @param operation Operation that is running.
 */
typedef void (^OCTFileBaseOperationProgressBlock)(OCTFileBaseOperation *__nonnull operation);

/**
 * Block to notify about operation success.
 *
 * @param operation Operation that is running.
 */
typedef void (^OCTFileBaseOperationSuccessBlock)(OCTFileBaseOperation *__nonnull operation);

/**
 * Block to notify about operation failure.
 *
 * @param operation Operation that is running.
 */
typedef void (^OCTFileBaseOperationFailureBlock)(OCTFileBaseOperation *__nonnull operation, NSError *__nonnull error);

typedef void (^OCTFileBaseOperationPullBlock)(OCTFileBaseOperation *__nonnull operation);

@interface OCTFileBaseOperation : NSOperation

/**
 * Identifier of operation, unique for all active file operations.
 */
@property (strong, nonatomic, readonly, nonnull) NSString *operationId;

@property BOOL isFileOperation;

/**
 * Progress properties.
 */
@property (assign, nonatomic, readonly) OCTToxFileSize bytesDone;
@property (assign, nonatomic, readonly) float progress;
@property (assign, nonatomic, readonly) OCTToxFileSize bytesPerSecond;
@property (assign, nonatomic, readonly) CFTimeInterval eta;

@property (strong, nonatomic, readonly, nullable) NSDictionary *userInfo;

/**
 * Creates operation id from file and friend number.
 */
+ (nonnull NSString *)operationIdFromFileNumber:(OCTToxFileNumber)fileNumber friendNumber:(OCTToxFriendNumber)friendNumber;

/**
 * Create operation.
 *
 * @param tox Tox object to load from.
 * @param friendNumber Number of friend.
 * @param fileNumber Number of file to load.
 * @param fileSize Size of file in bytes.
 * @param userInfo Any object that will be stored by operation.
 * @param progressBlock Block called to notify about loading progress. Block will be called on main thread.
 * @param etaUpdateBlock Block called to notify about loading eta update. Block will be called on main thread.
 * @param successBlock Block called on operation success. Block will be called on main thread.
 * @param failureBlock Block called on loading error. Block will be called on main thread.
 */
- (nullable instancetype)initWithTox:(nonnull OCTTox *)tox
                        friendNumber:(OCTToxFriendNumber)friendNumber
                          fileNumber:(OCTToxFileNumber)fileNumber
                            fileSize:(OCTToxFileSize)fileSize
                            userInfo:(nullable NSDictionary *)userInfo
                       progressBlock:(nullable OCTFileBaseOperationProgressBlock)progressBlock
                      etaUpdateBlock:(nullable OCTFileBaseOperationProgressBlock)etaUpdateBlock
                        successBlock:(nullable OCTFileBaseOperationSuccessBlock)successBlock
                        failureBlock:(nullable OCTFileBaseOperationFailureBlock)failureBlock;

- (nullable instancetype)init NS_UNAVAILABLE;
+ (nullable instancetype)new NS_UNAVAILABLE;

@end
