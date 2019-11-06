// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxAVConstants.h"
@import CoreVideo;

/**
 * This class helps with allocating and keeping CVPixelBuffers.
 */
@interface OCTPixelBufferPool : NSObject

- (instancetype)initWithFormat:(OSType)format;

/**
 * Grab a pixel buffer from the pool.
 * @param bufferRef Reference to the buffer ref.
 * @return YES on success, NO otherwise.
 */
- (BOOL)createPixelBuffer:(CVPixelBufferRef *)bufferRef width:(OCTToxAVVideoWidth)width height:(OCTToxAVVideoHeight)height;

@end
