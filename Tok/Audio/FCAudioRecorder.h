
#import <Foundation/Foundation.h>
#import "FCAudioMetadata.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FCAudioRecorderProgress) {
    FCAudioRecorderProgressWaitingForActivation,
    FCAudioRecorderProgressStarted,
    FCAudioRecorderProgressInterrupted
};

typedef NS_ENUM(NSUInteger, FCAudioRecorderCompletion) {
    FCAudioRecorderCompletionFailed,
    FCAudioRecorderCompletionFinished,
    FCAudioRecorderCompletionCancelled
};

FOUNDATION_EXTERN const NSErrorDomain FCAudioRecorderErrorDomain;

typedef NS_ENUM(NSUInteger, FCAudioRecorderErrorCode) {
    FCAudioRecorderErrorCodeAudioQueueNewInput,
    FCAudioRecorderErrorCodeAudioQueueGetStreamDescription,
    FCAudioRecorderErrorCodeAudioQueueAllocateBuffer,
    FCAudioRecorderErrorCodeAudioQueueEnqueueBuffer,
    FCAudioRecorderErrorCodeAudioQueueStart,
    FCAudioRecorderErrorCodeAudioQueueGetMaximumOutputPacketSize,
    FCAudioRecorderErrorCodeCreateAudioFile,
    FCAudioRecorderErrorCodeWriteAudioFile,
    FCAudioRecorderErrorCodeMediaServiceWereReset
};

typedef void (^FCAudioRecorderProgressCallback)(FCAudioRecorderProgress progress);
typedef void (^FCAudioRecorderCompletionCallback)(FCAudioRecorderCompletion completion, FCAudioMetadata* _Nullable metadata, NSError* _Nullable error);

@interface FCAudioRecorder : NSObject

@property (nonatomic, assign, readwrite) BOOL vibratesAtBeginning;
@property (nonatomic, assign, readonly, getter=isRecording) BOOL recording;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (void)recordForDuration:(NSTimeInterval)duration
                 progress:(FCAudioRecorderProgressCallback)progress
               completion:(FCAudioRecorderCompletionCallback)completion;
- (void)stop;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
