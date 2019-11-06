// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@protocol OCTFileInputProtocol <NSObject>

/**
 * Prepare input to read. This method will be called before first call to bytesWithPosition:length:.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)prepareToRead;

/**
 * Provide bytes.
 *
 * @param position Start position to start reading from.
 * @param length Length of bytes to read.
 *
 * @return NSData on success, nil on failure
 */
- (nonnull NSData *)bytesWithPosition:(OCTToxFileSize)position length:(size_t)length;

@end
