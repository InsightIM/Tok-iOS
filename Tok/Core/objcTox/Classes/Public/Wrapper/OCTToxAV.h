// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

#import "OCTToxAVConstants.h"
#import "OCTToxConstants.h"
#import "OCTToxAVDelegate.h"

@class OCTTox;

@interface OCTToxAV : NSObject

@property (weak, nonatomic) id<OCTToxAVDelegate> delegate;

#pragma mark -  Lifecycle

/**
 * Creates a new Toxav object.
 * @param tox Tox object to be initialized with.
 * @param error If an error occurs, this pointer is set to an actual error object.
 */
- (instancetype)initWithTox:(OCTTox *)tox error:(NSError **)error;

/**
 * Starts the main loop of the ToxAV on it's own unique queue.
 *
 * @warning ToxAV won't do anything without calling this method.
 */
- (void)start;

/**
 * Stops the main loop of the ToxAV.
 */
- (void)stop;

#pragma mark - Call Methods

/**
 * Call a friend. This will start ringing the friend.
 * It is the client's responsibility to stop ringing after a certain timeout,
 * if such behaviour is desired. If the client does not stop ringing, the
 * library will not stop until the friend is disconnected.
 * @param friendNumber The friend number of the friend that should be called.
 * @param audioBitRate Audio bit rate in Kb/sec. Set this to kOCTToxAVAudioBitRateDisable to disable audio sending.
 * @param videoBitRate Video bit rate in Kb/sec. Set this to kOCTToxAVVideoBitRateDisable to disable video sending.
 * video sending.
 * @param error If an error occurs, this pointer is set to an actual error object.
 */
- (BOOL)callFriendNumber:(OCTToxFriendNumber)friendNumber audioBitRate:(OCTToxAVAudioBitRate)audioBitRate videoBitRate:(OCTToxAVVideoBitRate)videoBitRate error:(NSError **)error;

/**
 * Accept an incoming call.
 *
 * If answering fails for any reason, the call will still be pending and it is
 * possible to try and answer it later.
 *
 * @param friendNumber The friend number of the friend that is calling.
 * @param audioBitRate Audio bit rate in Kb/sec. Set this to kOCTToxAVAudioBitRateDisable to disable
 * audio sending.
 * @param videoBitRate Video bit rate in Kb/sec. Set this to kOCTToxAVVideoBitRateDisable to disable
 * video sending.
 */
- (BOOL)answerIncomingCallFromFriend:(OCTToxFriendNumber)friendNumber audioBitRate:(OCTToxAVAudioBitRate)audioBitRate videoBitRate:(OCTToxAVVideoBitRate)videoBitrate error:(NSError **)error;

/**
 * Send a call control to a friend
 * @param control The control command to send.
 * @param friendNumber The friend number of the friend this client is in a call with.
 */
- (BOOL)sendCallControl:(OCTToxAVCallControl)control toFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error;

#pragma mark - Controlling bit rates
/**
 * Set the audio bit rate to be used in subsequent audio frames. If the passed
 * bit rate is the same as the current bit rate this function will return true
 * without calling a callback. If there is an active non forceful setup with the
 * passed audio bit rate and the new set request is forceful, the bit rate is
 * forcefully set and the previous non forceful request is cancelled. The active
 * non forceful setup will be canceled in favour of new non forceful setup.
 * @param bitRate The new audio bit rate in Kb/sec. Set to kOCTToxAVAudioBitRateDisable to disable audio sending.
 * @param friendNumber The friend for which to set the audio bit rate.
 * @param error If an error occurs, this pointer is set to an actual error object.
 */
- (BOOL)setAudioBitRate:(OCTToxAVAudioBitRate)bitRate force:(BOOL)force forFriend:(OCTToxFriendNumber)friendNumber error:(NSError **)error;

/**
 * Set the video bit rate to be used in subsequent video frames. If the passed
 * bit rate is the same as the current bit rate this function will return true
 * without calling a callback. If there is an active non forceful setup with the
 * passed video bit rate and the new set request is forceful, the bit rate is
 * forcefully set and the previous non forceful request is cancelled. The active
 * non forceful setup will be canceled in favour of new non forceful setup.
 * @param bitRate The new video bit rate in Kb/sec. Set to kOCTToxAVVideoBitRateDisable to disable video sending.
 * @param friendNumber The friend for which to set the video bit rate.
 * @param error If an error occurs, this pointer is set to an actual error object.
 */
- (BOOL)setVideoBitRate:(OCTToxAVVideoBitRate)bitRate force:(BOOL)force forFriend:(OCTToxFriendNumber)friendNumber error:(NSError **)error;

#pragma mark - Sending frames

/**
 * Send an audio frame to a friend.
 *
 * The expected format of the PCM data is: [s1c1][s1c2][...][s2c1][s2c2][...]...
 * Meaning: sample 1 for channel 1, sample 1 for channel 2, ...
 * For mono audio, this has no meaning, every sample is subsequent. For stereo,
 * this means the expected format is LRLRLR... with samples for left and right
 * alternating.
 * @param pcm An array of audio samples. The size of this array must be
 * sample_count * channels.
 * @param sampleCount Number of samples in this frame. Valid numbers here are
 * ((sample rate) * (audio length) / 1000), where audio length can be
 * 2.5, 5, 10, 20, 40 or 60 millseconds.
 * @param channels Number of audio channels. Supported values are 1 and 2.
 * @param samplingRate Audio sampling rate used in this frame. Valid sampling
 * rates are 8000, 12000, 16000, 24000, or 48000.
 * @param friendNumber The friend number of the friend to which to send an
 * audio frame.
 * @param error If an error occurs, this pointer is set to an actual error object.
 */
- (BOOL)sendAudioFrame:(OCTToxAVPCMData *)pcm sampleCount:(OCTToxAVSampleCount)sampleCount
              channels:(OCTToxAVChannels)channels sampleRate:(OCTToxAVSampleRate)sampleRate
              toFriend:(OCTToxFriendNumber)friendNumber error:(NSError **)error;

/**
 * Send a video frame to a friend.
 *
 * Y - plane should be of size: height * width
 * U - plane should be of size: (height/2) * (width/2)
 * V - plane should be of size: (height/2) * (width/2)
 *
 * @param friendNumber The friend number of the friend to which to send a video
 * frame.
 * @param width Width of the frame in pixels.
 * @param height Height of the frame in pixels.
 * @param y Y (Luminance) plane data.
 * @param u U (Chroma) plane data.
 * @param v V (Chroma) plane data.
 * @param error If an error occurs, this pointer is set to an actual error object.
 */
- (BOOL)sendVideoFrametoFriend:(OCTToxFriendNumber)friendNumber
                         width:(OCTToxAVVideoWidth)width height:(OCTToxAVVideoHeight)height
                        yPlane:(OCTToxAVPlaneData *)yPlane uPlane:(OCTToxAVPlaneData *)uPlane
                        vPlane:(OCTToxAVPlaneData *)vPlane
                         error:(NSError **)error;
@end
