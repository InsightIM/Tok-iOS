// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxAV.h"

@interface OCTAudioEngine : NSObject

@property (weak, nonatomic) OCTToxAV *toxav;
@property (nonatomic, assign) OCTToxFriendNumber friendNumber;

/**
 * YES to send audio frames over to tox, otherwise NO.
 * Default is YES.
 */
@property (nonatomic, assign) BOOL enableMicrophone;

/**
 * Starts the Audio Processing Graph.
 * @param error Pointer to error object.
 * @return YES on success, otherwise NO.
 */
- (BOOL)startAudioFlow:(NSError **)error;

/**
 * Stops the Audio Processing Graph.
 * @param error Pointer to error object.
 * @return YES on success, otherwise NO.
 */
- (BOOL)stopAudioFlow:(NSError **)error;

/**
 * Checks if the Audio Graph is processing.
 * @param error Pointer to error object.
 * @return YES if Audio Graph is running, otherwise NO.
 */
- (BOOL)isAudioRunning:(NSError **)error;

/**
 * Provide audio data that will be placed in buffer to be played in speaker.
 * @param pcm An array of audio samples (sample_count * channels elements).
 * @param sampleCount The number of audio samples per channel in the PCM array.
 * @param channels Number of audio channels.
 * @param sampleRate Sampling rate used in this frame.
 */
- (void)provideAudioFrames:(OCTToxAVPCMData *)pcm sampleCount:(OCTToxAVSampleCount)sampleCount channels:(OCTToxAVChannels)channels sampleRate:(OCTToxAVSampleRate)sampleRate fromFriend:(OCTToxFriendNumber)friendNumber;

@end

#if ! TARGET_OS_IPHONE

@interface OCTAudioEngine (MacDevice)

/**
 * Set the input device (not available on iOS).
 * @param inputDeviceID Core Audio's unique ID for the device. See
 *                      public OCTSubmanagerCalls.h for what these should be.
 * @param error If this method returns NO, contains more information on the
 *              underlying error.
 * @return YES on success, otherwise NO.
 */
- (BOOL)setInputDeviceID:(NSString *)inputDeviceID error:(NSError **)error;

/**
 * Set the output device (not available on iOS).
 * @param outputDeviceID Core Audio's unique ID for the device. See
 *                       public OCTSubmanagerCalls.h for what these should be.
 * @param error If this method returns NO, contains more information on the
 *              underlying error.
 * @return YES on success, otherwise NO.
 */
- (BOOL)setOutputDeviceID:(NSString *)outputDeviceID error:(NSError **)error;

@end

#else

@interface OCTAudioEngine (iOSDevice)

/**
 * Switch the output to/from the device's speaker.
 * @param speaker Whether we should use the speaker for output.
 * @param error If this method returns NO, contains more information on the
 *              underlying error.
 * @return YES on success, otherwise NO.
 */
- (BOOL)routeAudioToSpeaker:(BOOL)speaker error:(NSError **)error;

@end

#endif
