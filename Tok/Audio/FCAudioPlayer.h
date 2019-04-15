
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

typedef void (^FCAudioPlayerLoadFileCompletionCallback)(BOOL success, NSError* _Nullable error);

@interface FCAudioPlayer : NSObject

@property (nonatomic, assign, readonly) FCAudioPlaybackState state;
@property (nonatomic, assign, readonly) Float64 currentTime;
@property (nonatomic, copy, readonly) NSString *path;

+ (instancetype)sharedPlayer;

- (void)playFileAtPath:(NSString *)path completion:(FCAudioPlayerLoadFileCompletionCallback)completion;
- (void)play;
- (void)pause;
- (void)stopWithAudioSessionDeactivated:(BOOL)shouldDeactivate;
- (void)addObserver:(id<FCAudioPlayerObserver>)observer NS_SWIFT_NAME(addObserver(_:));
- (void)removeObserver:(id<FCAudioPlayerObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

@end

NS_ASSUME_NONNULL_END
