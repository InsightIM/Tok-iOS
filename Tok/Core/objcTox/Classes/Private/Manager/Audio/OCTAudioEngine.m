// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTAudioEngine+Private.h"
#import "OCTToxAV+Private.h"
#import "OCTAudioQueue.h"
#import "OCTLogging.h"

@import AVFoundation;

@interface OCTAudioEngine ()

@property (nonatomic, assign) OCTToxAVSampleRate outputSampleRate;
@property (nonatomic, assign) OCTToxAVChannels outputNumberOfChannels;

@end

@implementation OCTAudioEngine

#pragma mark - LifeCycle
- (instancetype)init
{
    self = [super init];
    if (! self) {
        return nil;
    }

    _outputSampleRate = kDefaultSampleRate;
    _outputNumberOfChannels = kNumberOfChannels;
    _enableMicrophone = YES;

    return self;
}

#pragma mark - SPI

#if ! TARGET_OS_IPHONE

- (BOOL)setInputDeviceID:(NSString *)inputDeviceID error:(NSError **)error
{
    // if audio is not active, we can't really be bothered to check that the
    // device exists; we rely on startAudioFlow: to fail later.
    if (! self.inputQueue) {
        _inputDeviceID = inputDeviceID;
        return YES;
    }

    if ([self.inputQueue setDeviceID:inputDeviceID error:error]) {
        _inputDeviceID = inputDeviceID;
        return YES;
    }

    return NO;
}

- (BOOL)setOutputDeviceID:(NSString *)outputDeviceID error:(NSError **)error
{
    if (! self.outputQueue) {
        _outputDeviceID = outputDeviceID;
        return YES;
    }

    if ([self.outputQueue setDeviceID:outputDeviceID error:error]) {
        _outputDeviceID = outputDeviceID;
        return YES;
    }

    return NO;
}

#else

- (BOOL)routeAudioToSpeaker:(BOOL)speaker error:(NSError **)error
{
    AVAudioSession *session = [AVAudioSession sharedInstance];

    AVAudioSessionPortOverride override;
    if (speaker) {
        override = AVAudioSessionPortOverrideSpeaker;
    }
    else {
        override = AVAudioSessionPortOverrideNone;
    }

    return [session overrideOutputAudioPort:override error:error];
}

#endif

- (BOOL)startAudioFlow:(NSError **)error
{
#if TARGET_OS_IPHONE
    AVAudioSession *session = [AVAudioSession sharedInstance];

    if (! ([session setCategory:AVAudioSessionCategoryPlayAndRecord error:error] &&
           [session setPreferredSampleRate:kDefaultSampleRate error:error] &&
           [session setMode:AVAudioSessionModeVoiceChat error:error] &&
           [session setActive:YES error:error])) {
        return NO;
    }
#endif

    [self makeQueues:error];

    if (! (self.outputQueue && self.inputQueue)) {
        return NO;
    }

    OCTAudioEngine *__weak welf = self;
    self.inputQueue.sendDataBlock = ^(void *data, OCTToxAVSampleCount samples, OCTToxAVSampleRate rate, OCTToxAVChannels channelCount) {
        OCTAudioEngine *aoi = welf;

        if (aoi.enableMicrophone) {
            [aoi.toxav sendAudioFrame:data
                          sampleCount:samples
                             channels:channelCount
                           sampleRate:rate
                             toFriend:aoi.friendNumber
                                error:nil];
        }
    };
    [self.outputQueue updateSampleRate:self.outputSampleRate numberOfChannels:self.outputNumberOfChannels error:nil];

    if (! [self.inputQueue begin:error] || ! [self.outputQueue begin:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)stopAudioFlow:(NSError **)error
{
    if (! [self.inputQueue stop:error] || ! [self.outputQueue stop:error]) {
        return NO;
    }

#if TARGET_OS_IPHONE
    AVAudioSession *session = [AVAudioSession sharedInstance];
    BOOL ret = [session setActive:NO error:error];
#else
    BOOL ret = YES;
#endif

    self.inputQueue = nil;
    self.outputQueue = nil;
    return ret;
}

- (void)provideAudioFrames:(OCTToxAVPCMData *)pcm sampleCount:(OCTToxAVSampleCount)sampleCount channels:(OCTToxAVChannels)channels sampleRate:(OCTToxAVSampleRate)sampleRate fromFriend:(OCTToxFriendNumber)friendNumber
{
    int32_t len = (int32_t)(channels * sampleCount * sizeof(OCTToxAVPCMData));
    TPCircularBuffer *buf = [self.outputQueue getBufferPointer];
    if (buf) {
        TPCircularBufferProduceBytes(buf, pcm, len);
    }

    if ((self.outputSampleRate != sampleRate) || (self.outputNumberOfChannels != channels)) {
        // failure is logged by OCTAudioQueue.
        [self.outputQueue updateSampleRate:sampleRate numberOfChannels:channels error:nil];

        self.outputSampleRate = sampleRate;
        self.outputNumberOfChannels = channels;
    }
}

- (BOOL)isAudioRunning:(NSError **)error
{
    return self.inputQueue.running && self.outputQueue.running;
}

- (void)makeQueues:(NSError **)error
{
    // Note: OCTAudioQueue handles the case where the device ids are nil - in that case
    // we don't set the device explicitly, and the default is used.
#if TARGET_OS_IPHONE
    self.outputQueue = [[OCTAudioQueue alloc] initWithOutputDeviceID:nil error:error];
    self.inputQueue = [[OCTAudioQueue alloc] initWithInputDeviceID:nil error:error];
#else
    self.outputQueue = [[OCTAudioQueue alloc] initWithOutputDeviceID:self.outputDeviceID error:error];
    self.inputQueue = [[OCTAudioQueue alloc] initWithInputDeviceID:self.inputDeviceID error:error];
#endif
}

@end
