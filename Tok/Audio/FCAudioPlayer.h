
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FCAudioPlayer;

typedef NS_ENUM(NSUInteger, FCAudioPlaybackState) {
    FCAudioPlaybackStatePreparing,
    FCAudioPlaybackStateReadyToPlay,
    FCAudioPlaybackStatePlaying,
    FCAudioPlaybackStatePaused,
    FCAudioPlaybackStateStopped,
    FCAudioPlaybackStateDisposed
};

FOUNDATION_EXTERN NSString* NSStringFromFCAudioPlaybackState(FCAudioPlaybackState state);

@protocol FCAudioPlayerObserver

- (void)fcAudioPlayer:(FCAudioPlayer *)player playbackStateDidChangeTo:(FCAudioPlaybackState)state;

@end

FOUNDATION_EXTERN const NSErrorDomain FCAudioPlayerErrorDomain;

typedef NS_ENUM(NSUInteger, FCAudioPlayerErrorCode) {
    FCAudioPlayerErrorCodeNewOutput,
    FCAudioPlayerErrorCodeAllocateBuffers,
    FCAudioPlayerErrorCodeAddPropertyListener,
    FCAudioPlayerErrorCodeStop,
    FCAudioPlayerErrorCodeCancelled
};

@interface FCAudioPlayer : NSObject

@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) Float64 currentTime;
@property (nonatomic, copy, readonly) NSString *path;

+ (instancetype)sharedPlayer;

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (void)play;
- (void)stop;
- (void)dispose;

@end

NS_ASSUME_NONNULL_END
