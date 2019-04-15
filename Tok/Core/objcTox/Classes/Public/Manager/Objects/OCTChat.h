// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTObject.h"
#import "OCTFriend.h"
#import "OCTPeer.h"
@class OCTMessageAbstract;

/**
 * Please note that all properties of this object are readonly.
 * You can change some of them only with appropriate method in OCTSubmanagerObjects.
 */
@interface OCTChat : OCTObject

@property NSInteger groupNumber;

@property BOOL isGroup;

@property (nullable) NSString *title;

/**
 * Array with OCTFriends that participate in this chat.
 */
@property (nullable) RLMArray<OCTFriend> *friends;

/**
 * The latest message that was send or received.
 */
@property (nullable) OCTMessageAbstract *lastMessage;

/**
 * This property can be used for storing entered text that wasn't send yet.
 *
 * To change please use OCTSubmanagerObjects method.
 *
 * May be empty.
 */
@property (nullable) NSString *enteredText;

/**
 * This property stores last date interval when chat was read.
 * `hasUnreadMessages` method use lastReadDateInterval to determine if there are unread messages.
 *
 * To change please use OCTSubmanagerObjects method.
 */
@property NSTimeInterval lastReadDateInterval;

/**
 * Date interval of lastMessage or chat creationDate if there is no last message.
 *
 * This property is workaround to support sorting. Should be replaced with keypath
 * lastMessage.dateInterval sorting in future.
 * See https://github.com/realm/realm-cocoa/issues/1277
 */
@property NSTimeInterval lastActivityDateInterval;

@property BOOL isMute;

/**
 * The date when chat was read last time.
 */
- (nullable NSDate *)lastReadDate;

/**
 * Returns date of lastMessage or chat creationDate if there is no last message.
 */
- (nullable NSDate *)lastActivityDate;

/**
 * If there are unread messages in chat YES is returned. All messages that have date later than lastReadDateInterval
 * are considered as unread.
 *
 * Please note that you have to set lastReadDateInterval to make this method work.
 *
 * @return YES if there are unread messages, NO otherwise.
 */
- (BOOL)hasUnreadMessages;

@end

RLM_ARRAY_TYPE(OCTChat)
