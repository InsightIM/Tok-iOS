// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFileBaseOperation.h"

@interface OCTFileBaseOperation (Private)

@property (weak, nonatomic, readonly, nullable) OCTTox *tox;

@property (assign, nonatomic, readonly) OCTToxFriendNumber friendNumber;
@property (assign, nonatomic, readwrite) OCTToxFileNumber fileNumber;
@property (assign, nonatomic, readonly) OCTToxFileSize fileSize;

- (void)startTimeout;
/**
 * Override this method to start custom actions. Call finish when operation is done.
 */
- (void)operationStarted NS_REQUIRES_SUPER;

/**
 * Override this method to do clean up on operation cancellation.
 */
- (void)operationWasCanceled NS_REQUIRES_SUPER;

/**
 * Call this method to change bytes done value.
 */
- (void)updateBytesDone:(OCTToxFileSize)bytesDone;

/**
 * Call this method in case if operation was finished.
 */
- (void)finishWithSuccess;

/**
 * Call this method in case if operation was finished or cancelled with error.
 *
 * @param error Pass error if occured, nil on success.
 */
- (void)finishWithError:(nonnull NSError *)error;

@end
