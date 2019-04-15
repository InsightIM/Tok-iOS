// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTView.h"

@import GLKit;

#if TARGET_OS_IPHONE
@interface OCTVideoView : GLKView
#else
@interface OCTVideoView : NSOpenGLView
#endif

@property (strong, nonatomic) CIImage *image;

/**
 * Allocs and calls the platform-specific initializers.
 */
+ (instancetype)view;

@end
