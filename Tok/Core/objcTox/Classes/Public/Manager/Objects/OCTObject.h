// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Realm/Realm.h>

/**
 * Please note that all properties of this object are readonly.
 * You can change some of them only with appropriate method in OCTSubmanagerObjects.
 */
@interface OCTObject : RLMObject

/**
 * The unique identifier of object.
 */
@property NSString *uniqueIdentifier;

/**
 * Returns a string that represents the contents of the receiving class.
 */
- (NSString *)description;

/**
 * Returns a Boolean value that indicates whether the receiver and a given object are equal.
 */
- (BOOL)isEqual:(id)object;

/**
 * Returns an integer that can be used as a table address in a hash table structure.
 */
- (NSUInteger)hash;

@end
