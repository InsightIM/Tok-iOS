// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFriend.h"

@interface OCTFriend ()

@end

@implementation OCTFriend

#pragma mark -  Class methods

+ (NSArray *)requiredProperties
{
    NSMutableArray *properties = [NSMutableArray arrayWithArray:[super requiredProperties]];

    [properties addObject:NSStringFromSelector(@selector(nickname))];
    [properties addObject:NSStringFromSelector(@selector(publicKey))];

    return [properties copy];
}

#pragma mark -  Public

- (NSDate *)lastSeenOnline
{
    if (self.lastSeenOnlineInterval <= 0) {
        return nil;
    }

    return [NSDate dateWithTimeIntervalSince1970:self.lastSeenOnlineInterval];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"OCTFriend with friendNumber %u, name %@", self.friendNumber, self.name];
}

@end
