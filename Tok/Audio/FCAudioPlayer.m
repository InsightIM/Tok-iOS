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

@interface FCAudioPlayer ()

@property (nonatomic, strong, readwrite) dispatch_queue_t processingQueue;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, strong, readwrite) FCOggOpusReader *reader;
@property (nonatomic, assign, readwrite) BOOL didReachEnd;

@end

@implementation FCAudioPlayer {
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _buffers[numberOfAudioQueueBuffers];
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
        _processingQueue = dispatch_queue_create("com.insight.tok.queue.audio_player", DISPATCH_QUEUE_SERIAL);
        _audioQueue = NULL;
        _didReachEnd = NO;
        _isPlaying = NO;
    }
    return self;
}

- (Float64)currentTime {
    if (!self.isPlaying) {
        return 0;
    }
    AudioTimeStamp timeStamp;
    AudioQueueGetCurrentTime(_audioQueue, NULL, &timeStamp, NULL);
    return timeStamp.mSampleTime / sampleRate;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError {
    if (self.isPlaying) {
        [self stop];
    }
    [self dispose];
    
    NSError *error = nil;
    _reader = [FCOggOpusReader readerWithFileAtPath:path error:&error];
    if (error) {
        if (outError) {
            *outError = error;
        }
        [self dispose];
        return NO;
    }
    
    AudioStreamBasicDescription format = CreateFormat();
    OSStatus result;
    result = AudioQueueNewOutput(&format, AQBufferCallback, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue);
    if (result != noErr) {
        if (outError) {
            *outError = ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCodeNewOutput, result);
        }
        [self dispose];
        return NO;
    }
    
    AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, isRunningChanged, (__bridge void *)(self));
    for (int i = 0; i < numberOfAudioQueueBuffers; ++i) {
        result = AudioQueueAllocateBuffer(_audioQueue, audioQueueBufferSize, &_buffers[i]);
        if (result != noErr) {
            if (outError) {
                *outError = ErrorWithCodeAndOSStatus(FCAudioPlayerErrorCodeAllocateBuffers, result);
            }
            [self dispose];
            return NO;
        }
    }
    
    AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, 1.0);
    return YES;
}

- (void)play {
    _didReachEnd = NO;
    for (int i = 0; i < numberOfAudioQueueBuffers; ++i) {
        AQBufferCallback((__bridge void *)self, _audioQueue, _buffers[i]);
    }
    AudioQueueStart(_audioQueue, NULL);
}

- (void)stop {
    self.isPlaying = NO;
    AudioQueueStop(_audioQueue, true);
}

- (void)dispose {
    if (_audioQueue) {
        AudioQueueDispose(_audioQueue, true);
        _audioQueue = NULL;
    }
    if (_reader) {
        [_reader close];
        _reader = nil;
    }
}

void AQBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    FCAudioPlayer *player = (__bridge FCAudioPlayer *)inUserData;
    if (player->_didReachEnd) {
        return;
    }
    NSData *pcmData = [player->_reader pcmDataWithMaxLength:audioQueueBufferSize error:nil];
    if (pcmData && pcmData.length > 0) {
        inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
        [pcmData getBytes:inBuffer->mAudioData length:pcmData.length];
        AudioQueueEnqueueBuffer(player->_audioQueue, inBuffer, 0, NULL);
    } else {
        player->_didReachEnd = YES;
        AudioQueueStop(inAQ, false);
    }
}

void isRunningChanged(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    FCAudioPlayer *player = (__bridge FCAudioPlayer*)inUserData;
    UInt32 isRunning;
    UInt32 size = sizeof(isRunning);
    OSStatus result = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
    if (result == noErr) {
        player.isPlaying = isRunning;
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
