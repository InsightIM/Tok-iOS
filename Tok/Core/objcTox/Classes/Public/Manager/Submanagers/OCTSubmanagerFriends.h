// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

@class OCTFriendRequest;
@class OCTFriend;

@protocol OCTSubmanagerFriends <NSObject>

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey;

/**
 * Send friend request to given address. Automatically adds friend with this address to friend list.
 *
 * @param address Address of a friend. If required.
 * @param message Message to send with friend request. Is required.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxErrorFriendAdd for all error codes.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)sendFriendRequestToAddress:(NSString *)address message:(NSString *)message error:(NSError **)error;

/**
 * Approve given friend request. After approving new friend will be added and friendRequest will be removed.
 *
 * @param friendRequest Friend request to approve.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxErrorFriendAdd for all error codes.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)approveFriendRequest:(OCTFriendRequest *)friendRequest error:(NSError **)error;

/**
 * Remove friend request from list. This cannot be undone.
 *
 * @param friendRequest Friend request to remove.
 */
- (void)removeFriendRequest:(OCTFriendRequest *)friendRequest;

/**
 * Remove friend from list. This cannot be undone.
 *
 * @param friend Friend to remove.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxErrorFriendDelete for all error codes.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)removeFriend:(OCTFriend *)friend error:(NSError **)error;

@end
