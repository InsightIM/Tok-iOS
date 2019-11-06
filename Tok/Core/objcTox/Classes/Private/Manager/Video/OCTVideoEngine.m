// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTVideoEngine.h"
#import "OCTVideoView.h"
#import "OCTPixelBufferPool.h"
#import "OCTManagerConstants.h"
#import "OCTLogging.h"

@import AVFoundation;

static const OSType kPixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;

@interface OCTVideoEngine () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *dataOutput;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, weak) OCTVideoView *videoView;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, assign) uint8_t *reusableUChromaPlane;
@property (nonatomic, assign) uint8_t *reusableVChromaPlane;
@property (nonatomic, assign) uint8_t *reusableYChromaPlane;
@property (strong, nonatomic) OCTPixelBufferPool *pixelPool;
@property (nonatomic, assign) NSUInteger sizeOfChromaPlanes;
@property (nonatomic, assign) NSUInteger sizeOfYPlane;

@end

@implementation OCTVideoEngine

#pragma mark - Life cycle

- (instancetype)init
{
    self = [super init];
    if (! self) {
        return nil;
    }

    OCTLogVerbose(@"init");

    // Disabling captureSession for simulator due to bug in iOS 10.
    // See https://forums.developer.apple.com/thread/62230
#if ! TARGET_OS_SIMULATOR
    _captureSession = [AVCaptureSession new];
    _captureSession.sessionPreset = AVCaptureSessionPresetMedium;

    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    }
#endif

    _dataOutput = [AVCaptureVideoDataOutput new];
    _processingQueue = dispatch_queue_create("im.insight.OCTVideoEngineQueue", NULL);
    _pixelPool = [[OCTPixelBufferPool alloc] initWithFormat:kPixelFormat];

    return self;
}

- (void)dealloc
{
    if (self.reusableUChromaPlane) {
        free(self.reusableUChromaPlane);
    }

    if (self.reusableVChromaPlane) {
        free(self.reusableVChromaPlane);
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public

- (BOOL)setupAndReturnError:(NSError **)error
{
    OCTLogVerbose(@"setupAndReturnError");
#if TARGET_OS_IPHONE
    AVCaptureDevice *videoCaptureDevice = [self getDeviceForPosition:AVCaptureDevicePositionFront];
#else
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
#endif
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:error];

    if (! videoInput) {
        return NO;
    }

    if ([self.captureSession canAddInput:videoInput]) {
        [self.captureSession addInput:videoInput];
    }

    self.dataOutput.alwaysDiscardsLateVideoFrames = YES;
    self.dataOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kPixelFormat),
    };
    [self.dataOutput setSampleBufferDelegate:self queue:self.processingQueue];

    [self.captureSession addOutput:self.dataOutput];
    AVCaptureConnection *conn = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];

    if (conn.supportsVideoOrientation) {
        [self registerOrientationNotification];
        [self orientationChanged];
    }

    return YES;
}

#if ! TARGET_OS_IPHONE

- (BOOL)switchToCamera:(NSString *)camera error:(NSError **)error
{
    AVCaptureDevice *dev = nil;

    if (! camera) {
        dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    else {
        dev = [AVCaptureDevice deviceWithUniqueID:camera];
    }

    return [self actuallySetCamera:dev error:error];
}

#else

- (BOOL)useFrontCamera:(BOOL)front error:(NSError **)error
{
    AVCaptureDevicePosition position = front ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;

    AVCaptureDevice *dev = [self getDeviceForPosition:position];

    return [self actuallySetCamera:dev error:error];
}

#endif

- (BOOL)actuallySetCamera:(AVCaptureDevice *)dev error:(NSError **)error
{
    OCTLogVerbose(@"actuallySetCamera: %@", dev);

    NSArray *inputs = [self.captureSession inputs];

    AVCaptureInput *current = [inputs firstObject];
    if ([current isKindOfClass:[AVCaptureDeviceInput class]]) {
        AVCaptureDeviceInput *inputDevice = (AVCaptureDeviceInput *)current;
        if ([inputDevice.device.uniqueID isEqualToString:dev.uniqueID]) {
            return YES;
        }
    }

    for (AVCaptureInput *input in inputs) {
        [self.captureSession removeInput:input];
    }

    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:dev error:error];

    if (! videoInput) {
        return NO;
    }

    if (! [self.captureSession canAddInput:videoInput]) {
        return NO;
    }

    [self.captureSession addInput:videoInput];

    [self orientationChanged];

    return YES;
}

- (void)startSendingVideo
{
    OCTLogVerbose(@"startSendingVideo");

    dispatch_async(self.processingQueue, ^{
        if ([self isSendingVideo]) {
            return;
        }
        [self.captureSession startRunning];
    });
}

- (void)stopSendingVideo
{
    OCTLogVerbose(@"stopSendingVideo");

    dispatch_async(self.processingQueue, ^{

        if (! [self isSendingVideo]) {
            return;
        }

        [self.captureSession stopRunning];
    });
}

- (BOOL)isSendingVideo
{
    OCTLogVerbose(@"isSendingVideo");
    return self.captureSession.isRunning;
}

- (void)getVideoCallPreview:(void (^)(CALayer *))completionBlock
{
    NSParameterAssert(completionBlock);
    OCTLogVerbose(@"videoCallPreview");
    dispatch_async(self.processingQueue, ^{
        AVCaptureVideoPreviewLayer *previewLayer = self.previewLayer;

        if (! self.previewLayer) {
            previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(previewLayer);
        });

        self.previewLayer = previewLayer;
    });
}

- (OCTView *)videoFeed;
{
    OCTLogVerbose(@"videoFeed");

    OCTVideoView *feed = self.videoView;

    if (! feed) {
        feed = [OCTVideoView view];
        self.videoView = feed;
    }

    return feed;
}

- (void)receiveVideoFrameWithWidth:(OCTToxAVVideoWidth)width
                            height:(OCTToxAVVideoHeight)height
                            yPlane:(OCTToxAVPlaneData *)yPlane
                            uPlane:(OCTToxAVPlaneData *)uPlane
                            vPlane:(OCTToxAVPlaneData *)vPlane
                           yStride:(OCTToxAVStrideData)yStride
                           uStride:(OCTToxAVStrideData)uStride
                           vStride:(OCTToxAVStrideData)vStride
                      friendNumber:(OCTToxFriendNumber)friendNumber
{

    if (! self.videoView) {
        return;
    }

    size_t yBytesPerRow = MIN(width, abs(yStride));
    size_t uvBytesPerRow = MIN(width / 2, abs(uStride));

    /**
     * Create pixel buffers and copy YUV planes over
     */
    CVPixelBufferRef bufferRef = NULL;

    if (! [self.pixelPool createPixelBuffer:&bufferRef width:width height:height]) {
        return;
    }

    CVPixelBufferLockBaseAddress(bufferRef, 0);

    OCTToxAVPlaneData *ySource = yPlane;
    // if stride is negative, start reading from the left of the last row
    if (yStride < 0) {
        ySource = ySource + ((-yStride) * (height - 1));
    }

    uint8_t *yDestinationPlane = CVPixelBufferGetBaseAddressOfPlane(bufferRef, 0);
    size_t yDestinationStride = CVPixelBufferGetBytesPerRowOfPlane(bufferRef, 0);

    /* Copy yPlane data */
    for (size_t yHeight = 0; yHeight < height; yHeight++) {
        memcpy(yDestinationPlane, ySource, yBytesPerRow);
        ySource += yStride;
        yDestinationPlane += yDestinationStride;
    }

    /* Interweave U and V */
    uint8_t *uvDestinationPlane = CVPixelBufferGetBaseAddressOfPlane(bufferRef, 1);
    size_t uvDestinationStride = CVPixelBufferGetBytesPerRowOfPlane(bufferRef, 1);

    OCTToxAVPlaneData *uSource = uPlane;
    if (uStride < 0) {
        uSource = uSource + ((-uStride) * ((height / 2) - 1));
    }

    OCTToxAVPlaneData *vSource = vPlane;
    if (vStride < 0) {
        vSource = vSource + ((-vStride) * ((height / 2) - 1));
    }

    for (size_t yHeight = 0; yHeight < height / 2; yHeight++) {
        for (size_t index = 0; index < uvBytesPerRow; index++) {
            uvDestinationPlane[index * 2] = uSource[index];
            uvDestinationPlane[(index * 2) + 1] = vSource[index];
        }
        uvDestinationPlane += uvDestinationStride;
        uSource += uStride;
        vSource += vStride;
    }

    CVPixelBufferUnlockBaseAddress(bufferRef, 0);

    dispatch_async(self.processingQueue, ^{
        /* Create Core Image */
        CIImage *coreImage = [CIImage imageWithCVPixelBuffer:bufferRef];

        CVPixelBufferRelease(bufferRef);

        self.videoView.image = coreImage;
    });
}

#pragma mark - Buffer Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (! imageBuffer) {
        return;
    }

    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    size_t yHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
    size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    size_t yStride = MAX(CVPixelBufferGetWidthOfPlane(imageBuffer, 0), yBytesPerRow);

    size_t uvHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, 1);
    size_t uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
    size_t uvStride = MAX(CVPixelBufferGetWidthOfPlane(imageBuffer, 1), uvBytesPerRow);

    size_t ySize = yBytesPerRow * yHeight;
    size_t numberOfElementsForChroma = uvBytesPerRow * uvHeight / 2;

    /**
     * Recreate the buffers if the original ones are too small
     */
    if (numberOfElementsForChroma > self.sizeOfChromaPlanes) {

        if (self.reusableUChromaPlane) {
            free(self.reusableUChromaPlane);
        }

        if (self.reusableVChromaPlane) {
            free(self.reusableVChromaPlane);
        }

        self.reusableUChromaPlane = malloc(numberOfElementsForChroma * sizeof(OCTToxAVPlaneData));
        self.reusableVChromaPlane = malloc(numberOfElementsForChroma * sizeof(OCTToxAVPlaneData));

        self.sizeOfChromaPlanes = numberOfElementsForChroma;
    }

    if (ySize > self.sizeOfYPlane) {
        if (self.reusableYChromaPlane) {
            free(self.reusableYChromaPlane);
        }
        self.reusableYChromaPlane = malloc(ySize * sizeof(OCTToxAVPlaneData));
        self.sizeOfYPlane = ySize;
    }

    /**
     * Copy the Y plane data while skipping stride
     */
    OCTToxAVPlaneData *yPlane = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    uint8_t *yDestination = self.reusableYChromaPlane;
    for (size_t i = 0; i < yHeight; i++) {
        memcpy(yDestination, yPlane, yBytesPerRow);
        yPlane += yStride;
        yDestination += yBytesPerRow;
    }

    /**
     * Deinterleaved the UV [uvuvuvuv] planes and place them to in the reusable arrays
     */
    OCTToxAVPlaneData *uvPlane = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
    uint8_t *uDestination = self.reusableUChromaPlane;
    uint8_t *vDestination = self.reusableVChromaPlane;

    for (size_t height = 0; height < uvHeight; height++) {

        for (size_t i = 0; i < uvBytesPerRow; i += 2) {
            uDestination[i / 2] = uvPlane[i];
            vDestination[i / 2] = uvPlane[i + 1];
        }

        uvPlane += uvStride;
        uDestination += uvBytesPerRow / 2;
        vDestination += uvBytesPerRow / 2;

    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    uDestination = nil;
    vDestination = nil;

    NSError *error;
    if (! [self.toxav sendVideoFrametoFriend:self.friendNumber
                                       width:(OCTToxAVVideoWidth)yBytesPerRow
                                      height:(OCTToxAVVideoHeight)yHeight
                                      yPlane:self.reusableYChromaPlane
                                      uPlane:self.reusableUChromaPlane
                                      vPlane:self.reusableVChromaPlane
                                       error:&error]) {
        OCTLogWarn(@"error:%@ width:%zu height:%zu", error, yBytesPerRow, yHeight);
    }
}

#pragma mark - Private

- (AVCaptureDevice *)getDeviceForPosition:(AVCaptureDevicePosition)position
{
    OCTLogVerbose(@"getDeviceForPosition");

    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }

    return nil;
}

- (void)registerOrientationNotification
{
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
#endif
}

- (void)orientationChanged
{
#if TARGET_OS_IPHONE
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    AVCaptureConnection *conn = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureVideoOrientation orientation;

    switch (deviceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        /* Landscapes are reversed, otherwise for some reason the video will be upside down */
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        default:
            return;
    }

    conn.videoOrientation = orientation;
    self.previewLayer.connection.videoOrientation = orientation;
#endif
}

@end
