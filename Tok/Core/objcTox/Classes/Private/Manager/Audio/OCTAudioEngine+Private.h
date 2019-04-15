// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTAudioEngine.h"
#import "TPCircularBuffer.h"

@import AVFoundation;

extern int kBufferLength;
extern int kNumberOfChannels;
extern int kDefaultSampleRate;
extern int kSampleCount;
extern int kBitsPerByte;
extern int kFramesPerPacket;
extern int kBytesPerSample;
extern int kNumberOfAudioQueueBuffers;

@class OCTAudioQueue;
@interface OCTAudioEngine ()

#if ! TARGET_OS_IPHONE
@property (strong, nonatomic, readonly) NSString *inputDeviceID;
@property (strong, nonatomic, readonly) NSString *outputDeviceID;
#endif

@property (nonatomic, strong) OCTAudioQueue *outputQueue;
@property (nonatomic, strong) OCTAudioQueue *inputQueue;

- (void)makeQueues:(NSError **)error;

@end
