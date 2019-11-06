// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTChat.h"
#import "OCTFriend.h"
#import "OCTManagerConstants.h"

/**
 * Please note that all properties of this object are readonly.
 * All management of calls are handeled through OCTCallSubmanagerCalls.
 */

@interface OCTCall : OCTObject

/**
 * OCTChat related session with the call.
 **/
@property (nonnull) OCTChat *chat;

/**
 * Call status
 **/
@property OCTCallStatus status;

/**
 * This property contains paused status for Active call.
 */
@property OCTCallPausedStatus pausedStatus;

/**
 * The friend who started the call.
 * Nil if the you started the call yourself.
 **/
@property (nullable) OCTFriend *caller;

/**
 * Video device is active for this call
 */
@property BOOL videoIsEnabled;

/**
 * Friend is sending audio.
 */
@property BOOL friendSendingAudio;

/**
 * Friend is sending video.
 */
@property BOOL friendSendingVideo;

/**
 * Friend is accepting audio.
 */
@property BOOL friendAcceptingAudio;

/**
 * Friend is accepting video.
 */
@property BOOL friendAcceptingVideo;

/**
 * Call duration
 **/
@property NSTimeInterval callDuration;

/**
 * The on hold start interval when call was put on hold.
 */
@property NSTimeInterval onHoldStartInterval;

/**
 * The date when the call was put on hold.
 */
- (nullable NSDate *)onHoldDate;

/**
 * Indicates if call is outgoing or incoming.
 * In case if it is incoming you can check `caller` property for friend.
 **/
- (BOOL)isOutgoing;

@end
