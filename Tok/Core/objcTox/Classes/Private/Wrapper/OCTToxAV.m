// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTTox+Private.h"
#import "OCTToxAV+Private.h"
#import "OCTLogging.h"

ToxAV *(*_toxav_new)(Tox *tox, TOXAV_ERR_NEW *error);
uint32_t (*_toxav_iteration_interval)(const ToxAV *toxAV);
void (*_toxav_iterate)(ToxAV *toxAV);
void (*_toxav_kill)(ToxAV *toxAV);

bool (*_toxav_call)(ToxAV *toxAV, uint32_t friend_number, uint32_t audio_bit_rate, uint32_t video_bit_rate, TOXAV_ERR_CALL *error);
bool (*_toxav_answer)(ToxAV *toxAV, uint32_t friend_number, uint32_t audio_bit_rate, uint32_t video_bit_rate, TOXAV_ERR_ANSWER *error);
bool (*_toxav_call_control)(ToxAV *toxAV, uint32_t friend_number, TOXAV_CALL_CONTROL control, TOXAV_ERR_CALL_CONTROL *error);

bool (*_toxav_audio_set_bit_rate)(ToxAV *av, uint32_t friend_number, uint32_t bit_rate, TOXAV_ERR_BIT_RATE_SET *error);
bool (*_toxav_video_set_bit_rate)(ToxAV *av, uint32_t friend_number, uint32_t bit_rate, TOXAV_ERR_BIT_RATE_SET *error);

bool (*_toxav_audio_send_frame)(ToxAV *toxAV, uint32_t friend_number, const int16_t *pcm, size_t sample_count, uint8_t channels, uint32_t sampling_rate, TOXAV_ERR_SEND_FRAME *error);
bool (*_toxav_video_send_frame)(ToxAV *toxAV, uint32_t friend_number, uint16_t width, uint16_t height, const uint8_t *y, const uint8_t *u, const uint8_t *v, TOXAV_ERR_SEND_FRAME *error);


@interface OCTToxAV ()

@property (assign, nonatomic) ToxAV *toxAV;

@property (strong, nonatomic) dispatch_source_t timer;

@property (assign, nonatomic) uint64_t previousIterate;

@end

@implementation OCTToxAV

#pragma mark -  Lifecycle
- (instancetype)initWithTox:(OCTTox *)tox error:(NSError **)error
{
    self = [super init];

    if (! self) {
        return nil;
    }

    OCTLogVerbose(@"init called");

    [self setupCFunctions];

    TOXAV_ERR_NEW cError;
    _toxAV = _toxav_new(tox.tox, &cError);

    [self fillError:error withCErrorInit:cError];

    [self setupCallbacks];

    return self;
}

- (void)start
{
    OCTLogVerbose(@"start method called");

    @synchronized(self) {
        if (self.timer) {
            OCTLogWarn(@"already started");
            return;
        }

        dispatch_queue_t queue = dispatch_queue_create("im.insight.OCTToxAVQueue", NULL);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

        [self updateTimerIntervalIfNeeded];

        __weak OCTToxAV *weakSelf = self;
        dispatch_source_set_event_handler(self.timer, ^{
            OCTToxAV *strongSelf = weakSelf;
            if (! strongSelf) {
                return;
            }

            _toxav_iterate(strongSelf.toxAV);

            [strongSelf updateTimerIntervalIfNeeded];
        });

        dispatch_resume(self.timer);
    }
    OCTLogInfo(@"started");
}

- (void)stop
{
    OCTLogVerbose(@"stop method called");

    @synchronized(self) {
        if (! self.timer) {
            OCTLogWarn(@"toxav isn't running, nothing to stop");
            return;
        }

        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }

    OCTLogInfo(@"stopped");
}

- (void)dealloc
{
    [self stop];
    _toxav_kill(self.toxAV);
    OCTLogVerbose(@"dealloc called, toxav killed");
}

#pragma mark - Call Methods

- (BOOL)callFriendNumber:(OCTToxFriendNumber)friendNumber audioBitRate:(OCTToxAVAudioBitRate)audioBitRate videoBitRate:(OCTToxAVVideoBitRate)videoBitRate error:(NSError **)error
{
    TOXAV_ERR_CALL cError;
    BOOL status = _toxav_call(self.toxAV, friendNumber, audioBitRate, videoBitRate, &cError);

    [self fillError:error withCErrorCall:cError];

    return status;
}

- (BOOL)answerIncomingCallFromFriend:(OCTToxFriendNumber)friendNumber audioBitRate:(OCTToxAVAudioBitRate)audioBitRate videoBitRate:(OCTToxAVVideoBitRate)videoBitrate error:(NSError **)error
{
    TOXAV_ERR_ANSWER cError;
    BOOL status = _toxav_answer(self.toxAV, friendNumber, audioBitRate, videoBitrate, &cError);

    [self fillError:error withCErrorAnswer:cError];

    return status;
}

- (BOOL)sendCallControl:(OCTToxAVCallControl)control toFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOXAV_CALL_CONTROL cControl;

    switch (control) {
        case OCTToxAVCallControlResume:
            cControl = TOXAV_CALL_CONTROL_RESUME;
            break;
        case OCTToxAVCallControlPause:
            cControl = TOXAV_CALL_CONTROL_PAUSE;
            break;
        case OCTToxAVCallControlCancel:
            cControl = TOXAV_CALL_CONTROL_CANCEL;
            break;
        case OCTToxAVCallControlMuteAudio:
            cControl = TOXAV_CALL_CONTROL_MUTE_AUDIO;
            break;
        case OCTToxAVCallControlUnmuteAudio:
            cControl = TOXAV_CALL_CONTROL_UNMUTE_AUDIO;
            break;
        case OCTToxAVCallControlHideVideo:
            cControl = TOXAV_CALL_CONTROL_HIDE_VIDEO;
            break;
        case OCTToxAVCallControlShowVideo:
            cControl = TOXAV_CALL_CONTROL_SHOW_VIDEO;
            break;
    }

    TOXAV_ERR_CALL_CONTROL cError;

    BOOL status = _toxav_call_control(self.toxAV, friendNumber, cControl, &cError);

    [self fillError:error withCErrorControl:cError];

    return status;
}

#pragma mark - Controlling bit rates

- (BOOL)setAudioBitRate:(OCTToxAVAudioBitRate)bitRate force:(BOOL)force forFriend:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOXAV_ERR_BIT_RATE_SET cError;

    BOOL status = _toxav_audio_set_bit_rate(self.toxAV, friendNumber, bitRate, &cError);

    [self fillError:error withCErrorSetBitRate:cError];

    OCTLogVerbose(@"setAudioBitRate:%lu, force:%d, friend:%d", (long)bitRate, force, friendNumber);

    return status;
}

- (BOOL)setVideoBitRate:(OCTToxAVVideoBitRate)bitRate force:(BOOL)force forFriend:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOXAV_ERR_BIT_RATE_SET cError;

    BOOL status = _toxav_video_set_bit_rate(self.toxAV, friendNumber, bitRate, &cError);

    [self fillError:error withCErrorSetBitRate:cError];

    return status;
}

#pragma mark - Sending frames
- (BOOL)sendAudioFrame:(OCTToxAVPCMData *)pcm sampleCount:(OCTToxAVSampleCount)sampleCount
              channels:(OCTToxAVChannels)channels sampleRate:(OCTToxAVSampleRate)sampleRate
              toFriend:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOXAV_ERR_SEND_FRAME cError;

    BOOL status = _toxav_audio_send_frame(self.toxAV, friendNumber,
                                          pcm, sampleCount,
                                          channels, sampleRate, &cError);

    [self fillError:error withCErrorSendFrame:cError];

    return status;
}

- (BOOL)sendVideoFrametoFriend:(OCTToxFriendNumber)friendNumber
                         width:(OCTToxAVVideoWidth)width height:(OCTToxAVVideoHeight)height
                        yPlane:(OCTToxAVPlaneData *)yPlane uPlane:(OCTToxAVPlaneData *)uPlane
                        vPlane:(OCTToxAVPlaneData *)vPlane
                         error:(NSError **)error
{
    TOXAV_ERR_SEND_FRAME cError;
    BOOL status = _toxav_video_send_frame(self.toxAV, friendNumber, width, height, yPlane, uPlane, vPlane, &cError);

    [self fillError:error withCErrorSendFrame:cError];

    return status;
}

#pragma mark - Private

- (void)setupCFunctions
{
    _toxav_new = toxav_new;
    _toxav_iteration_interval = toxav_iteration_interval;
    _toxav_iterate = toxav_iterate;
    _toxav_kill = toxav_kill;

    _toxav_call = toxav_call;
    _toxav_answer = toxav_answer;
    _toxav_call_control = toxav_call_control;

    _toxav_audio_set_bit_rate = toxav_audio_set_bit_rate;
    _toxav_video_set_bit_rate = toxav_video_set_bit_rate;

    _toxav_audio_send_frame = toxav_audio_send_frame;
    _toxav_video_send_frame = toxav_video_send_frame;
}

- (void)setupCallbacks
{
    toxav_callback_call(_toxAV, callIncomingCallback, (__bridge void *)(self));
    toxav_callback_call_state(_toxAV, callStateCallback, (__bridge void *)(self));
    toxav_callback_audio_bit_rate(_toxAV, audioBitRateStatusCallback, (__bridge void *)(self));
    toxav_callback_video_bit_rate(_toxAV, videoBitRateStatusCallback, (__bridge void *)(self));
    toxav_callback_audio_receive_frame(_toxAV, receiveAudioFrameCallback, (__bridge void *)(self));
    toxav_callback_video_receive_frame(_toxAV, receiveVideoFrameCallback, (__bridge void *)(self));
}

- (BOOL)fillError:(NSError **)error withCErrorInit:(TOXAV_ERR_NEW)cError
{
    if (! error || (cError == TOXAV_ERR_NEW_OK)) {
        return NO;
    }

    OCTToxAVErrorInitCode code = OCTToxAVErrorInitCodeUnknown;
    NSString *description = @"Cannot initialize ToxAV";
    NSString *failureReason = nil;

    switch (cError) {
        case TOXAV_ERR_NEW_OK:
            NSAssert(NO, @"We shouldn't be here!");
            break;
        case TOXAV_ERR_NEW_NULL:
            code = OCTToxAVErrorInitNULL;
            failureReason = @"One of the arguments to the function was NULL when it was not expected.";
            break;
        case TOXAV_ERR_NEW_MALLOC:
            code = OCTToxAVErrorInitCodeMemoryError;
            failureReason = @"Memory allocation failure while trying to allocate structures required for the A/V session.";
            break;
        case TOXAV_ERR_NEW_MULTIPLE:
            code = OCTToxAVErrorInitMultiple;
            failureReason = @"Attempted to create a second session for the same Tox instance.";
            break;
    }
    *error = [self createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorCall:(TOXAV_ERR_CALL)cError
{
    if (! error || (cError == TOXAV_ERR_CALL_OK)) {
        return NO;
    }

    OCTToxAVErrorCall code = OCTToxAVErrorCallUnknown;
    NSString *description = @"Could not make call";
    NSString *failureReason = nil;

    switch (cError) {
        case TOXAV_ERR_CALL_OK:
            NSAssert(NO, @"We shouldn't be here!");
            break;
        case TOXAV_ERR_CALL_MALLOC:
            code = OCTToxAVErrorCallMalloc;
            failureReason = @"A resource allocation error occured while trying to create the structures required for the call.";
            break;
        case TOXAV_ERR_CALL_SYNC:
            code = OCTToxAVErrorCallSync;
            failureReason = @"Synchronization error occurred.";
            break;
        case TOXAV_ERR_CALL_FRIEND_NOT_FOUND:
            code = OCTToxAVErrorCallFriendNotFound;
            failureReason = @"The friend number did not designate a valid friend.";
            break;
        case TOXAV_ERR_CALL_FRIEND_NOT_CONNECTED:
            code = OCTToxAVErrorCallFriendNotConnected;
            failureReason = @"The friend was valid, but not currently connected";
            break;
        case TOXAV_ERR_CALL_FRIEND_ALREADY_IN_CALL:
            code = OCTToxAVErrorCallAlreadyInCall;
            failureReason = @"Attempted to call a friend while already in an audio or video call with them.";
            break;
        case TOXAV_ERR_CALL_INVALID_BIT_RATE:
            code = OCTToxAVErrorCallInvalidBitRate;
            failureReason = @"Audio or video bit rate is invalid";
            break;
    }

    *error = [self createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorAnswer:(TOXAV_ERR_ANSWER)cError
{
    if (! error || (cError == TOXAV_ERR_ANSWER_OK)) {
        return NO;
    }

    OCTToxAVErrorAnswer code = OCTToxAVErrorAnswerUnknown;
    NSString *description = @"Could not answer call";
    NSString *failureReason = nil;

    switch (cError) {
        case TOXAV_ERR_ANSWER_OK:
            NSAssert(NO, @"We shouldn't be here!");
            break;
        case TOXAV_ERR_ANSWER_SYNC:
            code = OCTToxAVErrorAnswerSync;
            break;
        case TOXAV_ERR_ANSWER_CODEC_INITIALIZATION:
            code = OCTToxAVErrorAnswerCodecInitialization;
            break;
        case TOXAV_ERR_ANSWER_FRIEND_NOT_CALLING:
            code = OCTToxAVErrorAnswerFriendNotCalling;
            break;
        case TOXAV_ERR_ANSWER_FRIEND_NOT_FOUND:
            code = OCTToxAVErrorAnswerFriendNotFound;
            break;
        case TOXAV_ERR_ANSWER_INVALID_BIT_RATE:
            code = OCTToxAVErrorAnswerInvalidBitRate;
            break;
    }

    *error = [self createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorControl:(TOXAV_ERR_CALL_CONTROL)cError
{
    if (! error || (cError == TOXAV_ERR_CALL_CONTROL_OK)) {
        return NO;
    }

    OCTToxErrorCallControl code = OCTToxAVErrorControlUnknown;
    NSString *description = @"Unable set control";
    NSString *failureReason = nil;

    switch (cError) {
        case TOXAV_ERR_CALL_CONTROL_OK:
            NSAssert(NO, @"We shouldn't be here!");
            break;
        case TOXAV_ERR_CALL_CONTROL_SYNC:
            code = OCTToxAVErrorControlSync;
            failureReason = @"Synchronization error occurred.";
            break;
        case TOXAV_ERR_CALL_CONTROL_FRIEND_NOT_FOUND:
            code = OCTToxAVErrorControlFriendNotFound;
            failureReason = @"The friend number passed did not designate a valid friend.";
            break;
        case TOXAV_ERR_CALL_CONTROL_FRIEND_NOT_IN_CALL:
            code = OCTToxAVErrorControlFriendNotInCall;
            failureReason = @"This client is currently not in a call with the friend. Before the call is answered, only CANCEL is a valid control.";
            break;
        case TOXAV_ERR_CALL_CONTROL_INVALID_TRANSITION:
            code = OCTToxAVErrorControlInvaldTransition;
            failureReason = @"Happens if user tried to pause an already paused call or if trying to resume a call that is not paused.";
            break;
    }

    *error = [self createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorSetBitRate:(TOXAV_ERR_BIT_RATE_SET)cError
{
    if (! error || (cError == TOXAV_ERR_BIT_RATE_SET_OK)) {
        return NO;
    }

    OCTToxAVErrorSetBitRate code = OCTToxAVErrorSetBitRateUnknown;
    NSString *description = @"Unable to set audio/video bitrate";
    NSString *failureReason = nil;

    switch (cError) {
        case TOXAV_ERR_BIT_RATE_SET_OK:
            NSAssert(NO, @"We shouldn't be here!");
            break;
        case TOXAV_ERR_BIT_RATE_SET_SYNC:
            code = OCTToxAVErrorSetBitRateSync;
            failureReason = @"Synchronization error occurred.";
            break;
        case TOXAV_ERR_BIT_RATE_SET_INVALID_BIT_RATE:
            code = OCTToxAVErrorSetBitRateInvalidBitRate;
            failureReason = @"The bit rate passed was not one of the supported values.";
            break;
        case TOXAV_ERR_BIT_RATE_SET_FRIEND_NOT_FOUND:
            code = OCTToxAVErrorSetBitRateFriendNotFound;
            failureReason = @"The friend number passed did not designate a valid friend";
            break;
        case TOXAV_ERR_BIT_RATE_SET_FRIEND_NOT_IN_CALL:
            code = OCTToxAVErrorSetBitRateFriendNotInCall;
            failureReason = @"This client is currently not in a call with the friend";
            break;
    }

    *error = [self createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorSendFrame:(TOXAV_ERR_SEND_FRAME)cError
{
    if (! error || (cError == TOXAV_ERR_SEND_FRAME_OK)) {
        return NO;
    }

    OCTToxAVErrorSendFrame code = OCTToxAVErrorSendFrameUnknown;
    NSString *description = @"Failed to send audio/video frame";
    NSString *failureReason = @"Unable to sending audio/video frame";
    switch (cError) {
        case TOXAV_ERR_SEND_FRAME_OK:
            NSAssert(NO, @"We shouldn't be here!");
            break;
        case TOXAV_ERR_SEND_FRAME_NULL:
            code = OCTToxAVErrorSendFrameNull;
            failureReason = @"In case of video, one of Y, U, or V was NULL. In case of audio, the samples data pointer was NULL.";
            break;
        case TOXAV_ERR_SEND_FRAME_FRIEND_NOT_FOUND:
            code = OCTToxAVErrorSendFrameFriendNotFound;
            failureReason = @"The friend number passed did not designate a valid friend.";
            break;
        case TOXAV_ERR_SEND_FRAME_FRIEND_NOT_IN_CALL:
            code = OCTToxAVErrorSendFrameFriendNotInCall;
            failureReason = @"This client is currently not in a call with the friend";
            break;
        case TOXAV_ERR_SEND_FRAME_SYNC:
            code = OCTToxAVErrorSendFrameSync;
            failureReason = @"Synchronization error occurred";
            break;
        case TOXAV_ERR_SEND_FRAME_INVALID:
            code = OCTToxAVErrorSendFrameInvalid;
            failureReason = @"One of the frame parameters was invalid. E.g. the resolution may be too small or too large, or the audio sampling rate may be unsupported";
            break;
        case TOXAV_ERR_SEND_FRAME_PAYLOAD_TYPE_DISABLED:
            code = OCTToxAVErrorSendFramePayloadTypeDisabled;
            failureReason = @"Either friend turned off audio/video receiving or we turned off sending for the said payload.";
            break;
        case TOXAV_ERR_SEND_FRAME_RTP_FAILED:
            code = OCTToxAVErrorSendFrameRTPFailed;
            failureReason = @"Failed to push frame through rtp interface";
            break;
    }

    *error = [self createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

- (NSError *)createErrorWithCode:(NSUInteger)code
                     description:(NSString *)description
                   failureReason:(NSString *)failureReason
{
    NSMutableDictionary *userInfo = [NSMutableDictionary new];

    if (description) {
        userInfo[NSLocalizedDescriptionKey] = description;
    }

    if (failureReason) {
        userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
    }

    return [NSError errorWithDomain:kOCTToxAVErrorDomain code:code userInfo:userInfo];
}

- (void)updateTimerIntervalIfNeeded
{
    uint64_t nextIterate = _toxav_iteration_interval(self.toxAV) * (NSEC_PER_SEC / 1000);

    if (self.previousIterate == nextIterate) {
        return;
    }

    self.previousIterate = nextIterate;
    dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, nextIterate), nextIterate, nextIterate / 5);
}

@end

#pragma mark - Callbacks

void callIncomingCallback(ToxAV *cToxAV,
                          uint32_t friendNumber,
                          bool audioEnabled,
                          bool videoEnabled,
                          void *userData)
{
    OCTToxAV *toxAV = (__bridge OCTToxAV *)userData;

    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"callIncomingCallback from friend %lu with audio:%d with video:%d", toxAV, (unsigned long)friendNumber, audioEnabled, videoEnabled);
        if ([toxAV.delegate respondsToSelector:@selector(toxAV:receiveCallAudioEnabled:videoEnabled:friendNumber:)]) {
            [toxAV.delegate toxAV:toxAV receiveCallAudioEnabled:audioEnabled videoEnabled:videoEnabled friendNumber:friendNumber];
        }
    });
}

void callStateCallback(ToxAV *cToxAV,
                       uint32_t friendNumber,
                       enum TOXAV_FRIEND_CALL_STATE cState,
                       void *userData)
{
    OCTToxAV *toxAV = (__bridge OCTToxAV *)userData;

    dispatch_async(dispatch_get_main_queue(), ^{

        OCTLogCInfo(@"callStateCallback from friend %d with state: %d", toxAV, friendNumber, cState);

        OCTToxAVCallState state = 0;

        if (cState & TOXAV_FRIEND_CALL_STATE_ERROR) {
            state |= OCTToxAVFriendCallStateError;
        }
        if (cState & TOXAV_FRIEND_CALL_STATE_FINISHED) {
            state |= OCTToxAVFriendCallStateFinished;
        }
        if (cState & TOXAV_FRIEND_CALL_STATE_SENDING_A) {
            state |= OCTToxAVFriendCallStateSendingAudio;
        }
        if (cState & TOXAV_FRIEND_CALL_STATE_SENDING_V) {
            state |= OCTToxAVFriendCallStateSendingVideo;
        }
        if (cState & TOXAV_FRIEND_CALL_STATE_ACCEPTING_A) {
            state |= OCTToxAVFriendCallStateAcceptingAudio;
        }
        if (cState & TOXAV_FRIEND_CALL_STATE_ACCEPTING_V) {
            state |= OCTToxAVFriendCallStateAcceptingVideo;
        }

        if ([toxAV.delegate respondsToSelector:@selector(toxAV:callStateChanged:friendNumber:)]) {
            [toxAV.delegate toxAV:toxAV callStateChanged:state friendNumber:friendNumber];
        }
    });
}

void audioBitRateStatusCallback(ToxAV *cToxAV,
                                uint32_t friendNumber,
                                uint32_t bit_rate,
                                void *userData)
{
    OCTToxAV *toxAV = (__bridge OCTToxAV *)userData;

    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"audioBitRateStatusCallback from friend %d bitRate: %d", toxAV, friendNumber, bit_rate);
        if ([toxAV.delegate respondsToSelector:@selector(toxAV:audioBitRateStatus:forFriendNumber:)]) {
            [toxAV.delegate toxAV:toxAV audioBitRateStatus:bit_rate forFriendNumber:friendNumber];
        }
    });
}

void videoBitRateStatusCallback(ToxAV *cToxAV,
                                uint32_t friendNumber,
                                uint32_t bit_rate,
                                void *userData)
{
    OCTToxAV *toxAV = (__bridge OCTToxAV *)userData;

    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"videoBitRateStatusCallback from friend %d bitRate: %d", toxAV, friendNumber, bit_rate);
        if ([toxAV.delegate respondsToSelector:@selector(toxAV:videoBitRateStatus:forFriendNumber:)]) {
            [toxAV.delegate toxAV:toxAV videoBitRateStatus:bit_rate forFriendNumber:friendNumber];
        }
    });
}

void receiveAudioFrameCallback(ToxAV *cToxAV,
                               uint32_t friendNumber,
                               OCTToxAVPCMData *pcm,
                               OCTToxAVSampleCount sampleCount,
                               OCTToxAVChannels channels,
                               OCTToxAVSampleRate sampleRate,
                               void *userData)
{
    OCTToxAV *toxAV = (__bridge OCTToxAV *)userData;

    if ([toxAV.delegate respondsToSelector:@selector(toxAV:receiveAudio:sampleCount:channels:sampleRate:friendNumber:)]) {
        [toxAV.delegate toxAV:toxAV receiveAudio:pcm sampleCount:sampleCount channels:channels sampleRate:sampleRate friendNumber:friendNumber];
    }
}

void receiveVideoFrameCallback(ToxAV *cToxAV,
                               uint32_t friendNumber,
                               OCTToxAVVideoWidth width,
                               OCTToxAVVideoHeight height,
                               OCTToxAVPlaneData *yPlane, OCTToxAVPlaneData *uPlane, OCTToxAVPlaneData *vPlane,
                               OCTToxAVStrideData yStride, OCTToxAVStrideData uStride, OCTToxAVStrideData vStride,
                               void *userData)
{
    OCTToxAV *toxAV = (__bridge OCTToxAV *)userData;

    if ([toxAV.delegate respondsToSelector:@selector(toxAV:receiveVideoFrameWithWidth:height:yPlane:uPlane:vPlane:yStride:uStride:vStride:friendNumber:)]) {
        [toxAV.delegate toxAV:toxAV
         receiveVideoFrameWithWidth:width height:height
                             yPlane:yPlane uPlane:uPlane vPlane:vPlane
                            yStride:yStride uStride:uStride vStride:vStride
                       friendNumber:friendNumber];
    }

}
