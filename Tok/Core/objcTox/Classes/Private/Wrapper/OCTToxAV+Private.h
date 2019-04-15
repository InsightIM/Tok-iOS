// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTToxAV.h"
#import "toxav.h"

/**
 * ToxAV functions
 */

extern ToxAV *(*_toxav_new)(Tox *tox, TOXAV_ERR_NEW *error);
extern uint32_t (*_toxav_iteration_interval)(const ToxAV *toxAV);
extern void (*_toxav_iterate)(ToxAV *toxAV);
extern void (*_toxav_kill)(ToxAV *toxAV);

extern bool (*_toxav_call)(ToxAV *toxAV, uint32_t friend_number, uint32_t audio_bit_rate, uint32_t video_bit_rate, TOXAV_ERR_CALL *error);
extern bool (*_toxav_answer)(ToxAV *toxAV, uint32_t friend_number, uint32_t audio_bit_rate, uint32_t video_bit_rate, TOXAV_ERR_ANSWER *error);
extern bool (*_toxav_call_control)(ToxAV *toxAV, uint32_t friend_number, TOXAV_CALL_CONTROL control, TOXAV_ERR_CALL_CONTROL *error);

extern bool (*_toxav_audio_set_bit_rate)(ToxAV *av, uint32_t friend_number, uint32_t bit_rate, TOXAV_ERR_BIT_RATE_SET *error);
extern bool (*_toxav_video_set_bit_rate)(ToxAV *av, uint32_t friend_number, uint32_t bit_rate, TOXAV_ERR_BIT_RATE_SET *error);

extern bool (*_toxav_audio_send_frame)(ToxAV *toxAV, uint32_t friend_number, const int16_t *pcm, size_t sample_count, uint8_t channels, uint32_t sampling_rate, TOXAV_ERR_SEND_FRAME *error);
extern bool (*_toxav_video_send_frame)(ToxAV *toxAV, uint32_t friend_number, uint16_t width, uint16_t height, const uint8_t *y, const uint8_t *u, const uint8_t *v, TOXAV_ERR_SEND_FRAME *error);

/**
 * Callbacks
 */
toxav_call_cb callIncomingCallback;
toxav_call_state_cb callStateCallback;
toxav_audio_bit_rate_cb audioBitRateStatusCallback;
toxav_video_bit_rate_cb videoBitRateStatusCallback;
toxav_audio_receive_frame_cb receiveAudioFrameCallback;
toxav_video_receive_frame_cb receiveVideoFrameCallback;

@interface OCTToxAV (Private)

@property (assign, nonatomic) ToxAV *toxAV;

- (BOOL)fillError:(NSError **)error withCErrorInit:(TOXAV_ERR_NEW)cError;
- (BOOL)fillError:(NSError **)error withCErrorCall:(TOXAV_ERR_CALL)cError;
- (BOOL)fillError:(NSError **)error withCErrorAnswer:(TOXAV_ERR_ANSWER)cError;
- (BOOL)fillError:(NSError **)error withCErrorControl:(TOXAV_ERR_CALL_CONTROL)cError;
- (BOOL)fillError:(NSError **)error withCErrorSetBitRate:(TOXAV_ERR_BIT_RATE_SET)cError;
- (BOOL)fillError:(NSError **)error withCErrorSendFrame:(TOXAV_ERR_SEND_FRAME)cError;
- (NSError *)createErrorWithCode:(NSUInteger)code
                     description:(NSString *)description
                   failureReason:(NSString *)failureReason;

@end
