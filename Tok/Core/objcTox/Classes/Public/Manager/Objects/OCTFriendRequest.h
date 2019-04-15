// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTObject.h"

/**
 * Please note that all properties of this object are readonly.
 * You can change some of them only with appropriate method in OCTSubmanagerObjects.
 */
@interface OCTFriendRequest : OCTObject

/**
 * Public key of a friend.
 */
@property (nonnull) NSString *publicKey;

/**
 * Message that friend did send with friend request.
 */
@property (nullable) NSString *message;

/**
 * Date interval when friend request was received (since 1970).
 */
@property NSTimeInterval dateInterval;

/**
 * Date when friend request was received.
 */
- (nonnull NSDate *)date;

@end

RLM_ARRAY_TYPE(OCTFriendRequest)
