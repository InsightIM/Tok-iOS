
#import "FCAudioPlayer.h"
#import "FCOggOpusReader.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

const NSErrorDomain FCAudioPlayerErrorDomain = @"FCAudioRecorderErrorDomain";

static const Float64 sampleRate = 48000;
static const int numberOfAudioQueueBuffers = 3;
static const UInt32 audioQueueBufferSize = 65536;

NS_INLINE NSError* ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCode code, OSStatus status);
NS_INLINE AudioStreamBasicDescription CreateFormat(void);

@implementation FCAudioPlayer {
    dispatch_queue_t _processingQueue;
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _buffers[numberOfAudioQueueBuffers];
    AudioQueueTimelineRef _timeline;
    FCOggOpusReader *_reader;
    NSHashTable<id<FCAudioPlayerObserver>> *_observers;
}

+ (instancetype)sharedPlayer {
    static FCAudioPlayer *sharedPlayer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlayer = [[FCAudioPlayer alloc] init];
    });
    return sharedPlayer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processingQueue = dispatch_queue_create("one.mixin.queue.audio_player", DISPATCH_QUEUE_SERIAL);
        _audioQueue = NULL;
        _observers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        _state = FCAudioPlaybackStatePreparing;
    }
    return self;
}

- (Float64)currentTime {
    if (_state != FCAudioPlaybackStatePlaying) {
        return 0;
    }
    AudioTimeStamp timeStamp;
    AudioQueueGetCurrentTime(_audioQueue, _timeline, &timeStamp, NULL);
    return timeStamp.mSampleTime / sampleRate;
}

- (void)playFileAtPath:(NSString *)path completion:(FCAudioPlayerLoadFileCompletionCallback)completion {
    if ([path isEqualToString:_path]) {
        switch (_state) {
            case FCAudioPlaybackStatePreparing: {
                // Not expected to happend
                return;
            }
            case FCAudioPlaybackStateReadyToPlay:
            case FCAudioPlaybackStatePlaying:
            case FCAudioPlaybackStatePaused:
            case FCAudioPlaybackStateStopped: {
                [self play];
                completion(YES, nil);
                return;
            }
            case FCAudioPlaybackStateDisposed: {
                break;
            }
        }
    } else {
        [self stopWithAudioSessionDeactivated:NO];
        [self dispose];
        _path = path;
    }
    dispatch_async(_processingQueue, ^{
        NSError *error = nil;

        if (self->_path != path) {
            error = [NSError errorWithDomain:FCAudioPlayerErrorDomain
                                        code:FCAudioPlayerErrorCodeCancelled
                                    userInfo:nil];
            completion(NO, error);
            return;
        }
        
        [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStatePreparing];
        
        FCOggOpusReader *reader = [FCOggOpusReader readerWithFileAtPath:path error:&error];
        if (!reader) {
            completion(NO, error);
            return;
        }

        self->_reader = reader;
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        BOOL success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                       mode:AVAudioSessionModeDefault
                                    options:AVAudioSessionCategoryOptionAllowBluetoothA2DP
                                      error:&error];
        if (!success) {
            [self dispose];
            completion(NO, error);
            return;
        }
        
        success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (!success) {
            [self dispose];
            completion(NO, error);
            return;
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
        
        AudioStreamBasicDescription format = CreateFormat();
        OSStatus result;
        result = AudioQueueNewOutput(&format, AQBufferCallback, (__bridge void *)(self), NULL, NULL, 0, &self->_audioQueue);
        if (result != noErr) {
            error = ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCodeNewOutput, result);
            [self dispose];
            completion(NO, error);
            return;
        }
        
        for (int i = 0; i < numberOfAudioQueueBuffers; ++i) {
            result = AudioQueueAllocateBuffer(self->_audioQueue, audioQueueBufferSize, &self->_buffers[i]);
            if (result != noErr) {
                error = ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCodeNewOutput, result);
                [self dispose];
                completion(NO, error);
                return;
            }
            AQBufferCallback((__bridge void *)(self), self->_audioQueue, self->_buffers[i]);
        }
        
        result = AudioQueueAddPropertyListener(self->_audioQueue, kAudioQueueProperty_IsRunning, isRunningChanged, (__bridge void * _Nullable)(self));
        if (result != noErr) {
            error = ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCodeAddPropertyListener, result);
            [self dispose];
            completion(NO, error);
        }
        
        AudioQueueCreateTimeline(self->_audioQueue, &self->_timeline);
        
        AudioQueueSetParameter(self->_audioQueue, kAudioQueueParam_Volume, 1.0);
        
        [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStateReadyToPlay];
        [self play];
        completion(YES, nil);
    });
}

- (void)play {
//    [self handleProximityMonitoring:YES];
    if (_state == FCAudioPlaybackStateStopped) {
        [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStatePreparing];
        [_reader seekToZero];
        for (int i = 0; i < numberOfAudioQueueBuffers; i++) {
            AQBufferCallback((__bridge void *)(self), self->_audioQueue, self->_buffers[i]);
        }
        [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStateReadyToPlay];
    }
    if (_state == FCAudioPlaybackStateStopped || _state == FCAudioPlaybackStateReadyToPlay || _state == FCAudioPlaybackStatePaused) {
        AudioQueueStart(_audioQueue, NULL);
        [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStatePlaying];
    }
}

- (void)pause {
//    [self handleProximityMonitoring:NO];
    if (_state != FCAudioPlaybackStatePlaying) {
        return;
    }
    AudioQueuePause(_audioQueue);
    [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStatePaused];
}

- (void)stopWithAudioSessionDeactivated:(BOOL)shouldDeactivate {
//    [self handleProximityMonitoring:NO];
    if (_state == FCAudioPlaybackStateStopped || _state == FCAudioPlaybackStateDisposed) {
        return;
    }
    [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStateStopped];
    AudioQueueStop(_audioQueue, TRUE);
    if (shouldDeactivate) {
        dispatch_async(_processingQueue, ^{
            BOOL shouldDeactivate = self->_state == FCAudioPlaybackStateStopped || self->_state == FCAudioPlaybackStateDisposed;
            if (shouldDeactivate) {
                AudioQueueStop(self->_audioQueue, TRUE);
                [[AVAudioSession sharedInstance] setActive:NO
                                               withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                     error:nil];
            }
        });
    }
}

- (void)dispose {
    if (_state != FCAudioPlaybackStateStopped) {
        [self stopWithAudioSessionDeactivated:YES];
    }
    if (_timeline) {
        AudioQueueDisposeTimeline(_audioQueue, _timeline);
        _timeline = nil;
    }
    if (_audioQueue) {
        AudioQueueDispose(_audioQueue, TRUE);
        _audioQueue = nil;
    }
    if (_reader) {
        [_reader close];
        _reader = nil;
    }
    [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStateDisposed];
}

- (void)addObserver:(id<FCAudioPlayerObserver>)observer {
    [_observers addObject:observer];
}

- (void)removeObserver:(id<FCAudioPlayerObserver>)observer {
    [_observers removeObject:observer];
}

- (void)setPlaybackStateAndNotifyObservers:(FCAudioPlaybackState)state {
    _state = state;
    NSArray *observers = _observers.allObjects;
    for (id<FCAudioPlayerObserver> observer in observers) {
        [observer fcAudioPlayer:self playbackStateDidChangeTo:state];
    }
}

- (void)audioSessionInterruption:(NSNotification *)notification {
    [self stopWithAudioSessionDeactivated:YES];
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
                [self stopWithAudioSessionDeactivated:YES];
            }
            break;
        }
        case AVAudioSessionRouteChangeReasonUnknown:
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory: {
            [self stopWithAudioSessionDeactivated:YES];
            break;
        }
    }
}

- (void)audioSessionMediaServicesWereReset:(NSNotification *)notification {
    _audioQueue = nil;
    if (_reader) {
        [_reader close];
        _reader = nil;
    }
    [self setPlaybackStateAndNotifyObservers:FCAudioPlaybackStateDisposed];
}

#pragma mark - 监听听筒or扬声器

- (void)handleProximityMonitoring:(BOOL)enabled {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIDevice currentDevice] setProximityMonitoringEnabled:enabled];
    });
    
    if (enabled) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sensorStateChange:) name:UIDeviceProximityStateDidChangeNotification
                                                   object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIDeviceProximityStateDidChangeNotification
                                                      object:nil];
    }
}

// proximityState 属性 如果用户接近手机，此时属性值为YES，并且屏幕关闭（非休眠）。
- (void)sensorStateChange:(NSNotificationCenter *)notification {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([[UIDevice currentDevice] proximityState] == YES) {
        [session setCategory:AVAudioSessionCategoryPlayAndRecord
                        mode:AVAudioSessionModeDefault
                     options:AVAudioSessionCategoryOptionAllowBluetoothA2DP
                       error:nil];
    } else {
        [session setCategory:AVAudioSessionCategoryPlayAndRecord
                        mode:AVAudioSessionModeDefault
                     options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetoothA2DP
                       error:nil];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    }
}

void AQBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    FCAudioPlayer *player = (__bridge FCAudioPlayer *)inUserData;
    if (player->_state == FCAudioPlaybackStateStopped || player->_state == FCAudioPlaybackStateDisposed) {
        return;
    }
    NSData *pcmData = [player->_reader pcmDataWithMaxLength:audioQueueBufferSize error:nil];
    if (pcmData && pcmData.length > 0) {
        inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
        [pcmData getBytes:inBuffer->mAudioData length:pcmData.length];
        AudioQueueEnqueueBuffer(player->_audioQueue, inBuffer, 0, NULL);
    } else {
        if (player->_state == FCAudioPlaybackStatePlaying) {
            [player stopWithAudioSessionDeactivated:YES];
        }
    }
}

void isRunningChanged(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    FCAudioPlayer *player = (__bridge FCAudioPlayer*)inUserData;
    UInt32 isRunning;
    UInt32 size = sizeof(isRunning);
    OSStatus result = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
    if (result == noErr && !isRunning && player->_state != FCAudioPlaybackStateStopped) {
        NSLog(@"isRunningChanged post stoped. previous: %@", NSStringFromFCAudioPlaybackState(player->_state));
        [player setPlaybackStateAndNotifyObservers:FCAudioPlaybackStateStopped];
    }
}

@end

NS_INLINE NSError* ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCode code, OSStatus status) {
    NSDictionary *userInfo = @{@"os_status" : @(status)};
    return [NSError errorWithDomain:FCAudioPlayerErrorDomain
                               code:code
                           userInfo:userInfo];
}

NS_INLINE AudioStreamBasicDescription CreateFormat(void) {
    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = sampleRate;
    format.mChannelsPerFrame = 1;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mBitsPerChannel = 16;
    format.mBytesPerPacket = format.mBytesPerFrame = (format.mBitsPerChannel / 8) * format.mChannelsPerFrame;
    format.mFramesPerPacket = 1;
    return format;
}

NSString* NSStringFromFCAudioPlaybackState(FCAudioPlaybackState state) {
    switch (state) {
        case FCAudioPlaybackStatePreparing:
            return @"Preparing";
        case FCAudioPlaybackStateReadyToPlay:
            return @"ReadyToPlay";
        case FCAudioPlaybackStatePlaying:
            return @"Playing";
        case FCAudioPlaybackStatePaused:
            return @"Paused";
        case FCAudioPlaybackStateStopped:
            return @"Stopped";
        case FCAudioPlaybackStateDisposed:
            return @"Disposed";
    }
}
