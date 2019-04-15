// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

typedef const int16_t OCTToxAVPCMData;
typedef size_t OCTToxAVSampleCount;
typedef uint8_t OCTToxAVChannels;
typedef uint32_t OCTToxAVSampleRate;

typedef int OCTToxAVVideoBitRate;
typedef uint16_t OCTToxAVVideoWidth;
typedef uint16_t OCTToxAVVideoHeight;
typedef const uint8_t OCTToxAVPlaneData;
typedef const int32_t OCTToxAVStrideData;

extern const OCTToxAVVideoBitRate kOCTToxAVVideoBitRateDisable;

extern NSString *const kOCTToxAVErrorDomain;

/*******************************************************************************
 *
 * Call state graph
 *
 ******************************************************************************/

typedef NS_OPTIONS(NSInteger, OCTToxAVCallState) {

    /**
     * The call is paused by the friend.
     */
    OCTToxAVFriendCallStatePaused = 0,

    /**
     * Set by the AV core if an error occurred on the remote end or if friend
     * timed out. This is the final state after which no more state
     * transitions can occur for the call. This call state will never be triggered
     * in combination with other call states.
     */
    OCTToxAVFriendCallStateError = 1 << 0,

        /**
         * The call has finished. This is the final state after which no more state
         * transitions can occur for the call. This call state will never be
         * triggered in combination with other call states.
         */
        OCTToxAVFriendCallStateFinished = 1 << 1,

        /**
         * The flag that marks that friend is sending audio.
         */
        OCTToxAVFriendCallStateSendingAudio = 1 << 2,

        /**
         * The flag that marks that friend is sending video.
         */
        OCTToxAVFriendCallStateSendingVideo = 1 << 3,

        /**
         * The flag that marks that friend is accepting audio.
         */
        OCTToxAVFriendCallStateAcceptingAudio = 1 << 4,

        /**
         * The flag that marks that friend is accepting video.
         */
        OCTToxAVFriendCallStateAcceptingVideo = 1 << 5,
};

/*******************************************************************************
 *
 * Error Codes
 *
 ******************************************************************************/

/**
 * Error codes for init method.
 */
typedef NS_ENUM(NSInteger, OCTToxAVErrorInitCode) {
    OCTToxAVErrorInitCodeUnknown,
    /**
     * One of the arguments to the function was NULL when it was not expected.
     */
    OCTToxAVErrorInitNULL,

    /**
     * Memory allocation failure while trying to allocate structures required for
     * the A/V session.
     */
    OCTToxAVErrorInitCodeMemoryError,

    /**
     * Attempted to create a second session for the same Tox instance.
     */
    OCTToxAVErrorInitMultiple,
};

/**
 * Error codes for call setup.
 */
typedef NS_ENUM(NSInteger, OCTToxAVErrorCall) {
    OCTToxAVErrorCallUnknown,

    /**
     * A resource allocation error occurred while trying to create the structures
     * required for the call.
     */
    OCTToxAVErrorCallMalloc,

    /**
     * Synchronization error occurred.
     */
    OCTToxAVErrorCallSync,

    /**
     * The friend number did not designate a valid friend.
     */
    OCTToxAVErrorCallFriendNotFound,

    /**
     * The friend was valid, but not currently connected.
     */
    OCTToxAVErrorCallFriendNotConnected,

    /**
     * Attempted to call a friend while already in an audio or video call with
     * them.
     */
    OCTToxAVErrorCallAlreadyInCall,

    /**
     * Audio or video bit rate is invalid.
     */
    OCTToxAVErrorCallInvalidBitRate,
};

/**
 * Error codes for answer calls.
 */
typedef NS_ENUM(NSInteger, OCTToxAVErrorAnswer) {
    OCTToxAVErrorAnswerUnknown,

    /**
     * Synchronization error occurred.
     */
    OCTToxAVErrorAnswerSync,

    /**
     * Failed to initialize codecs for call session. Note that codec initiation
     * will fail if there is no receive callback registered for either audio or
     * video.
     */
    OCTToxAVErrorAnswerCodecInitialization,

    /**
     * The friend number did not designate a valid friend.
     */
    OCTToxAVErrorAnswerFriendNotFound,

    /**
     * The friend was valid, but they are not currently trying to initiate a call.
     * This is also returned if this client is already in a call with the friend.
     */
    OCTToxAVErrorAnswerFriendNotCalling,

    /**
     * Audio or video bit rate is invalid.
     */
    OCTToxAVErrorAnswerInvalidBitRate,
};

/**
 * Error codes for when sending controls.
 */
typedef NS_ENUM(NSInteger, OCTToxErrorCallControl) {
    OCTToxAVErrorControlUnknown,

    /**
     * Synchronization error occurred.
     */
    OCTToxAVErrorControlSync,

    /**
     * The friend number passed did not designate a valid friend.
     */
    OCTToxAVErrorControlFriendNotFound,

    /**
     * This client is currently not in a call with the friend. Before the call is
     * answered, only CANCEL is a valid control.
     */
    OCTToxAVErrorControlFriendNotInCall,

    /**
     * Happens if user tried to pause an already paused call or if trying to
     * resume a call that is not paused.
     */
    OCTToxAVErrorControlInvaldTransition,

};

/**
 * Error codes for setting the bit rate.
 */
typedef NS_ENUM(NSInteger, OCTToxAVErrorSetBitRate) {
    OCTToxAVErrorSetBitRateUnknown,

    /**
     * Synchronization error occured.
     */
    OCTToxAVErrorSetBitRateSync,

    /**
     * The bit rate passed was not one of the supported values.<Paste>
     */
    OCTToxAVErrorSetBitRateInvalidBitRate,

    /**
     * The friend number passed did not designate a valid friend.
     */
    OCTToxAVErrorSetBitRateFriendNotFound,

    /**
     * This client is currently not in a call with the friend.
     */
    OCTToxAVErrorSetBitRateFriendNotInCall,
};

/**
 * Error codes for sending audio/video frames
 */
typedef NS_ENUM(NSInteger, OCTToxAVErrorSendFrame) {
    OCTToxAVErrorSendFrameUnknown,

    /**
     * In case of video, one of Y, U, or V was NULL. In case of audio, the samples
     * data pointer was NULL.
     */
    OCTToxAVErrorSendFrameNull,

    /**
     * The friend number passed did not designate a valid friend.
     */
    OCTToxAVErrorSendFrameFriendNotFound,

    /**
     * This client is currently not in a call with the friend.
     */
    OCTToxAVErrorSendFrameFriendNotInCall,

    /**
     * Synchronization error occurred.
     */
    OCTToxAVErrorSendFrameSync,

    /**
     * One of the frame parameters was invalid. E.g. the resolution may be too
     * small or too large, or the audio sampling rate may be unsupported.
     */
    OCTToxAVErrorSendFrameInvalid,

    /**
     * Bit rate for this payload type was not set up.
     */
    OCTToxAVErrorSendFramePayloadTypeDisabled,

    /**
     * Failed to push frame through rtp interface.
     */
    OCTToxAVErrorSendFrameRTPFailed,
};

/*******************************************************************************
 *
 * Call control
 *
 ******************************************************************************/
typedef NS_ENUM(NSInteger, OCTToxAVCallControl) {
    /**
     * Resume a previously paused call. Only valid if the pause was caused by this
     * client, if not, this control is ignored. Not valid before the call is accepted.
     */
    OCTToxAVCallControlResume,

    /**
     * Put a call on hold. Not valid before the call is accepted.
     */
    OCTToxAVCallControlPause,

    /**
     * Reject a call if it was not answered, yet. Cancel a call after it was
     * answered.
     */
    OCTToxAVCallControlCancel,

    /**
     * Request that the friend stops sending audio. Regardless of the friend's
     * compliance, this will cause the audio_receive_frame event to stop being
     * triggered on receiving an audio frame from the friend.
     */
    OCTToxAVCallControlMuteAudio,

    /**
     * Calling this control will notify client to start sending audio again.
     */
    OCTToxAVCallControlUnmuteAudio,

    /**
     * Request that the friend stops sending video. Regardless of the friend's
     * compliance, this will cause the video_receive_frame event to stop being
     * triggered on receiving an video frame from the friend.
     */
    OCTToxAVCallControlHideVideo,

    /**
     * Calling this control will notify client to start sending video again.
     */
    OCTToxAVCallControlShowVideo,
};

/*******************************************************************************
 *
 * Audio Bitrates. All bitrates are in kb/s.
 *
 ******************************************************************************/
typedef NS_ENUM(NSInteger, OCTToxAVAudioBitRate) {
    OCTToxAVAudioBitRateDisabled = 0,

    OCTToxAVAudioBitRate8 = 8,

    OCTToxAVAudioBitRate16 = 16,

    OCTToxAVAudioBitRate24 = 24,

    OCTToxAVAudioBitRate32 = 32,

    OCTToxAVAudioBitRate48 = 48,
};
