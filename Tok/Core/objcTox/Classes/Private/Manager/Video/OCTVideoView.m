// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTVideoView.h"
@import Foundation;
@import AVFoundation;

@interface OCTVideoView ()

@property (strong, nonatomic) CIContext *coreImageContext;

@end

@implementation OCTVideoView

+ (instancetype)view
{
#if TARGET_OS_IPHONE
    OCTVideoView *videoView = [[self alloc] initWithFrame:CGRectZero];
#else
    OCTVideoView *videoView = [[self alloc] initWithFrame:CGRectZero pixelFormat:[self defaultPixelFormat]];
#endif
    [videoView finishInitializing];
    return videoView;
}

- (void)finishInitializing
{
#if TARGET_OS_IPHONE
    __weak OCTVideoView *weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        OCTVideoView *strongSelf = weakSelf;
        strongSelf.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        strongSelf.coreImageContext = [CIContext contextWithEAGLContext:strongSelf.context];
    });

    self.enableSetNeedsDisplay = NO;
#endif
}

- (void)setImage:(CIImage *)image
{
    _image = image;
#if TARGET_OS_IPHONE
    [self display];
#else
    [self setNeedsDisplay:YES];
#endif
}

#if ! TARGET_OS_IPHONE
// OS X: we need to correct the viewport when the view size changes
- (void)reshape
{
    glViewport(0, 0, self.bounds.size.width, self.bounds.size.height);
}
#endif

- (void)drawRect:(CGRect)rect
{
#if TARGET_OS_IPHONE
    if (self.image) {

        glClearColor(0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);

        CGRect destRect = AVMakeRectWithAspectRatioInsideRect(self.image.extent.size, rect);

        float screenscale = self.window.screen.scale;

        destRect = CGRectApplyAffineTransform(destRect, CGAffineTransformMakeScale(screenscale, screenscale));

        [self.coreImageContext drawImage:self.image inRect:destRect fromRect:self.image.extent];
    }
#else
    [self.openGLContext makeCurrentContext];

    if (self.image) {
        CIContext *ctx = [CIContext contextWithCGLContext:self.openGLContext.CGLContextObj pixelFormat:self.openGLContext.pixelFormat.CGLPixelFormatObj colorSpace:nil options:nil];
        // The GL coordinate system goes from -1 to 1 on all axes by default.
        // We didn't set a matrix so use that instead of bounds.
        [ctx drawImage:self.image inRect:(CGRect) {-1, -1, 2, 2} fromRect:self.image.extent];
    }
    else {
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    glFlush();
#endif
}
@end
