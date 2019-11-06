
#import "FCAudioRecorder.h"
#import "FCOggOpusWriter.h"
#import <AVFoundation/AVFoundation.h>

#define ReturnNoIfOSStautsError(result, code) if (result != noErr) { \
                                                if (outError) { \
                                                    *outError = ErrorWithCodeAndOSStatus(code, result); \
                                                } \
                                                return NO; \
                                              } \

const NSErrorDomain FCAudioRecorderErrorDomain = @"FCAudioRecorderErrorDomain";

static const float bufferDuration = 0.5;
static const int numberOfAudioQueueBuffers = 3;
static const int recordingSampleRate = 16000;
static const int millisecondsPerSecond = 1000;
static const int waveformPeakSampleScope = 100;
static const int numberOfWaveformIntensities = 63;

NS_INLINE NSError* ErrorWithCodeAndOSStatus(FCAudioRecorderErrorCode code, OSStatus status);
NS_INLINE AudioStreamBasicDescription CreateFormat(void);

@implementation FCAudioRecorder {
    dispatch_queue_t _processingQueue;
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef buffers[numberOfAudioQueueBuffers];
    NSTimeInterval _duration;
    FCOggOpusWriter *_writer;
    FCAudioRecorderCompletionCallback _completion;
    NSTimer *_timer;
    NSMutableData *_waveformSamples;
    int16_t _waveformPeak;
    int _waveformPeakCount;
    int _numberOfEncodedSamples;
}

- (nullable instancetype)initWithPath:(NSString *)path error:(NSError * _Nullable *)outError {
    self = [super init];
    if (self) {
        _vibratesAtBeginning = YES;
        _processingQueue = dispatch_queue_create("one.mixin.queue.audio_recorder", DISPATCH_QUEUE_SERIAL);
        _audioQueue = NULL;
        _writer = [FCOggOpusWriter writerWithPath:path
                                   inputSampleRate:recordingSampleRate
                                             error:outError];
        if (!_writer) {
            return nil;
        }
        _recording = NO;
        _waveformPeak = 0;
        _waveformPeakCount = 0;
        _numberOfEncodedSamples = 0;
    };
    return self;
}

- (void)recordForDuration:(NSTimeInterval)duration
                 progress:(FCAudioRecorderProgressCallback)progress
               completion:(FCAudioRecorderCompletionCallback)completion {
    if ([AVAudioSession sharedInstance].secondaryAudioShouldBeSilencedHint) {
        progress(FCAudioRecorderProgressWaitingForActivation);
    }
    __weak FCAudioRecorder *weakSelf = self;
    dispatch_async(_processingQueue, ^{
        if (!weakSelf) {
            return;
        }
        FCAudioRecorder *strongSelf = weakSelf;
        
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        BOOL success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                       mode:AVAudioSessionModeDefault
                                    options:AVAudioSessionCategoryOptionAllowBluetooth
                                      error:&error];
        if (!success) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(FCAudioRecorderCompletionFailed, nil, error);
            });
            return;
        }
        
        success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (!success) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(FCAudioRecorderCompletionFailed, nil, error);
            });
            return;
        }

        if (strongSelf->_vibratesAtBeginning) {
            AudioServicesPlaySystemSound(1519);
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(audioSessionInterruption:)
                       name:AVAudioSessionInterruptionNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(audioSessionRouteChange:)
                       name:AVAudioSessionRouteChangeNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(audioSessionMediaServicesWereReset:)
                       name:AVAudioSessionMediaServicesWereResetNotification
                     object:nil];
        
        strongSelf->_duration = duration;
        success = [self performRecording:&error];
        if (success) {
            strongSelf->_completion = [completion copy];
            dispatch_sync(dispatch_get_main_queue(), ^{
                progress(FCAudioRecorderProgressStarted);
            });
        } else {
            [strongSelf deactivateAudioSessionAndRemoveObservers];
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(FCAudioRecorderCompletionFailed, nil, error);
            });
        }
    });
}

- (void)stop {
    dispatch_async(_processingQueue, ^{
        if (!self->_recording) {
            return;
        }
        NSData *waveform = [self waveform];
        NSUInteger duration = self->_numberOfEncodedSamples * millisecondsPerSecond / recordingSampleRate;
        FCAudioMetadata *metadata = [FCAudioMetadata metadataWithDuration:duration waveform:waveform];
        [self cleanUp];
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_completion(FCAudioRecorderCompletionFinished, metadata, nil);
        });
    });
}

- (void)cancel {
    dispatch_async(_processingQueue, ^{
        if (!self->_recording) {
            return;
        }
        [self cleanUp];
        [self->_writer removeFile];
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_completion(FCAudioRecorderCompletionCancelled, nil, nil);
        });
    });
}

// MARK: - Private works
- (void)audioSessionInterruption:(NSNotification *)notification {
    [self cancel];
}

- (void)audioSessionRouteChange:(NSNotification *)notification {
    AVAudioSessionRouteChangeReason reason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonOverride:
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange: {
            break;
        }
        case AVAudioSessionRouteChangeReasonCategoryChange: {
            NSString *newCategory = [[AVAudioSession sharedInstance] category];
            BOOL canContinue = [newCategory isEqualToString:AVAudioSessionCategoryRecord] || [newCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord];
            if (!canContinue) {
                [self cancel];
            }
            break;
        }
        case AVAudioSessionRouteChangeReasonUnknown:
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory: {
            [self cancel];
            break;
        }
    }
}

- (void)audioSessionMediaServicesWereReset:(NSNotification *)notification {
    NSError *error = [NSError errorWithDomain:FCAudioRecorderErrorDomain
                                         code:FCAudioRecorderErrorCodeMediaServiceWereReset
                                     userInfo:nil];
    _recording = NO;
    _completion(FCAudioRecorderCompletionFailed, nil, error);
}

- (BOOL)performRecording:(NSError **)outError {
    _waveformSamples = [NSMutableData data];
    
    AudioStreamBasicDescription format = CreateFormat();
    OSStatus result = noErr;

    result = AudioQueueNewInput(&format, inputBufferhandler, (__bridge void *)(self), NULL, NULL, 8, &_audioQueue);
    ReturnNoIfOSStautsError(result, FCAudioRecorderErrorCodeAudioQueueNewInput);
    
    UInt32 size = sizeof(format);
    result = AudioQueueGetProperty(_audioQueue, kAudioQueueProperty_StreamDescription, &format, &size);
    ReturnNoIfOSStautsError(result, FCAudioRecorderErrorCodeAudioQueueGetStreamDescription);
    
    int bufferSize = [self bufferSizeWithFormat:&format seconds:bufferDuration error:outError];
    if (bufferSize == -1) {
        return NO;
    }
    
    for (int i = 0; i < numberOfAudioQueueBuffers; ++i) {
        result = AudioQueueAllocateBuffer(_audioQueue, bufferSize, &buffers[i]);
        ReturnNoIfOSStautsError(result, FCAudioRecorderErrorCodeAudioQueueAllocateBuffer);
        result = AudioQueueEnqueueBuffer(_audioQueue, buffers[i], 0, NULL);
        ReturnNoIfOSStautsError(result, FCAudioRecorderErrorCodeAudioQueueEnqueueBuffer);
    }
    
    result = AudioQueueStart(_audioQueue, NULL);
    ReturnNoIfOSStautsError(result, FCAudioRecorderErrorCodeAudioQueueStart)
    
    _timer = [NSTimer timerWithTimeInterval:_duration repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self stop];
    }];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    
    _recording = YES;
    return YES;
}

- (void)deactivateAudioSessionAndRemoveObservers {
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cleanUp {
    _recording = NO;
    [_timer invalidate];
    _timer = nil;
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose(_audioQueue, true);
    [_writer close];
    _waveformSamples = nil;
    [self deactivateAudioSessionAndRemoveObservers];
}

- (NSData *)waveform {
    uint8_t *intensities = malloc(numberOfWaveformIntensities);
    memset(intensities, 0, numberOfWaveformIntensities);
    NSUInteger numberOfRawSamples = _waveformSamples.length / 2;
    int16_t *rawSamples = (int16_t *)_waveformSamples.bytes;
    int16_t minRawSample = INT16_MAX;
    int16_t maxRawSample = 0;
    for (int i = 0; i < numberOfRawSamples; i++) {
        minRawSample = MIN(minRawSample, rawSamples[i]);
        maxRawSample = MAX(maxRawSample, rawSamples[i]);
    }
    float delta = (float)UINT8_MAX / (float)(maxRawSample - minRawSample);
    for (int i = 0; i < numberOfRawSamples; i++) {
        int index = i * numberOfWaveformIntensities / numberOfRawSamples;
        intensities[index] = rawSamples[i] * delta;
    }
    return [NSData dataWithBytesNoCopy:intensities length:numberOfWaveformIntensities freeWhenDone:YES];
}

- (void)processWaveformSamplesWithPCMData:(NSData *)data {
    [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
        NSUInteger numberOfSamples = byteRange.length / 2;
        for (int i = 0; i < numberOfSamples; i++) {
            int16_t sample = ((const int16_t *)bytes)[i];
            sample = abs(sample);
            self->_waveformPeak = MAX(sample, self->_waveformPeak);
            self->_waveformPeakCount++;
            if (self->_waveformPeakCount >= waveformPeakSampleScope) {
                [self->_waveformSamples appendBytes:&self->_waveformPeak length:2];
                self->_waveformPeak = 0;
                self->_waveformPeakCount = 0;
            }
        }
    }];
}

// Return -1 if failed
- (int)bufferSizeWithFormat:(const AudioStreamBasicDescription *)format
                    seconds:(float)seconds
                      error:(NSError **)outError {
    int packets, bytes = 0;
    int frames = (int)ceil(seconds * format->mSampleRate);
    if (format->mBytesPerFrame > 0) {
        bytes = frames * format->mBytesPerPacket;
    } else {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0) {
            maxPacketSize = format->mBytesPerPacket;
        } else {
            UInt32 propertySize = sizeof(maxPacketSize);
            OSStatus result = AudioQueueGetProperty(_audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &propertySize);
            if (result != noErr) {
                if (outError) {
                    *outError = ErrorWithCodeAndOSStatus(FCAudioRecorderErrorCodeAudioQueueGetMaximumOutputPacketSize, result);
                }
                return -1;
            }
        }
        if (format->mFramesPerPacket > 0) {
            packets = frames / format->mFramesPerPacket;
        } else {
            packets = frames;
        }
        if (packets == 0) {
            packets = 1;
        }
        bytes = packets * maxPacketSize;
    }
    return bytes;
}

void inputBufferhandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumberPacketDescriptions, const AudioStreamPacketDescription *inPacketDescs) {
    FCAudioRecorder *recorder = (__bridge FCAudioRecorder *)inUserData;
    OSStatus result = noErr;
    if (inNumberPacketDescriptions > 0) {
        NSData *pcmData = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        __weak FCAudioRecorder *weakRecorder = recorder;
        dispatch_async(recorder->_processingQueue, ^{
            FCAudioRecorder *strongRecorder = weakRecorder;
            if (!strongRecorder || !strongRecorder->_recording) {
                return;
            }
            strongRecorder->_numberOfEncodedSamples += pcmData.length / 2;
            [strongRecorder->_writer writePCMData:pcmData];
            [strongRecorder processWaveformSamplesWithPCMData:pcmData];
        });
    }
    if (recorder->_recording) {
        result = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
        if (result != noErr) {
            [recorder cancel];
            return;
        }
    }
}

@end

NS_INLINE NSError* ErrorWithCodeAndOSStatus(FCAudioRecorderErrorCode code, OSStatus status) {
    NSDictionary *userInfo = @{@"os_status" : @(status)};
    return [NSError errorWithDomain:FCAudioRecorderErrorDomain
                               code:code
                           userInfo:userInfo];
}

NS_INLINE AudioStreamBasicDescription CreateFormat(void) {
    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = recordingSampleRate;
    format.mChannelsPerFrame = 1;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mBitsPerChannel = 16;
    format.mBytesPerPacket = format.mBytesPerFrame = (format.mBitsPerChannel / 8) * format.mChannelsPerFrame;
    format.mFramesPerPacket = 1;
    return format;
}
