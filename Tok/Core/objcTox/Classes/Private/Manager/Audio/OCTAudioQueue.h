// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "TPCircularBuffer.h"

@import AudioToolbox;

#pragma mark - C declarations

extern OSStatus (*_AudioQueueAllocateBuffer)(AudioQueueRef inAQ,
                                             UInt32 inBufferByteSize,
                                             AudioQueueBufferRef *outBuffer);
extern OSStatus (*_AudioQueueDispose)(AudioQueueRef inAQ,
                                      Boolean inImmediate);
extern OSStatus (*_AudioQueueEnqueueBuffer)(AudioQueueRef inAQ,
                                            AudioQueueBufferRef inBuffer,
                                            UInt32 inNumPacketDescs,
                                            const AudioStreamPacketDescription *inPacketDescs);
extern OSStatus (*_AudioQueueFreeBuffer)(AudioQueueRef inAQ,
                                         AudioQueueBufferRef inBuffer);
extern OSStatus (*_AudioQueueNewInput)(const AudioStreamBasicDescription *inFormat,
                                       AudioQueueInputCallback inCallbackProc,
                                       void *inUserData,
                                       CFRunLoopRef inCallbackRunLoop,
                                       CFStringRef inCallbackRunLoopMode,
                                       UInt32 inFlags,
                                       AudioQueueRef *outAQ);
extern OSStatus (*_AudioQueueNewOutput)(const AudioStreamBasicDescription *inFormat,
                                        AudioQueueOutputCallback inCallbackProc,
                                        void *inUserData,
                                        CFRunLoopRef inCallbackRunLoop,
                                        CFStringRef inCallbackRunLoopMode,
                                        UInt32 inFlags,
                                        AudioQueueRef *outAQ);
extern OSStatus (*_AudioQueueSetProperty)(AudioQueueRef inAQ,
                                          AudioQueuePropertyID inID,
                                          const void *inData,
                                          UInt32 inDataSize);
extern OSStatus (*_AudioQueueStart)(AudioQueueRef inAQ,
                                    const AudioTimeStamp *inStartTime);
extern OSStatus (*_AudioQueueStop)(AudioQueueRef inAQ,
                                   Boolean inImmediate);
#if ! TARGET_OS_IPHONE
extern OSStatus (*_AudioObjectGetPropertyData)(AudioObjectID inObjectID,
                                               const AudioObjectPropertyAddress *inAddress,
                                               UInt32 inQualifierDataSize,
                                               const void *inQualifierData,
                                               UInt32 *ioDataSize,
                                               void *outData);
#endif

/* no idea what to name this thing, so here it is */
@interface OCTAudioQueue : NSObject

@property (strong, nonatomic, readonly) NSString *deviceID;
@property (copy, nonatomic) void (^sendDataBlock)(void *, OCTToxAVSampleCount, OCTToxAVSampleRate, OCTToxAVChannels);
@property (assign, nonatomic, readonly) BOOL running;

- (instancetype)initWithInputDeviceID:(NSString *)devID error:(NSError **)error;
- (instancetype)initWithOutputDeviceID:(NSString *)devID error:(NSError **)error;

- (TPCircularBuffer *)getBufferPointer;
- (BOOL)updateSampleRate:(OCTToxAVSampleRate)sampleRate numberOfChannels:(OCTToxAVChannels)numberOfChannels error:(NSError **)err;

#if ! TARGET_OS_IPHONE
- (BOOL)setDeviceID:(NSString *)deviceID error:(NSError **)err;
#endif

- (BOOL)begin:(NSError **)error;
- (BOOL)stop:(NSError **)error;

@end
