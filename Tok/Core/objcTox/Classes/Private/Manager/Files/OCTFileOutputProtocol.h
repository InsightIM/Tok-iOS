// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

@protocol OCTFileOutputProtocol <NSObject>

/**
 * Prepare input to write. This method will be called before first call to writeData:.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)prepareToWrite;

/**
 * Write data to output.
 *
 * @param data Data to write.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)writeData:(nonnull NSData *)data;

/**
 * This method is called after last writeData: method.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)finishWriting;

/**
 * This method is called if all progress was canceled. Do needed cleanup.
 */
- (void)cancel;

@end
