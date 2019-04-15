// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFriendRequest.h"

@implementation OCTFriendRequest

#pragma mark -  Class methods

+ (NSArray *)requiredProperties
{
    NSMutableArray *properties = [NSMutableArray arrayWithArray:[super requiredProperties]];

    [properties addObject:NSStringFromSelector(@selector(publicKey))];

    return [properties copy];
}

#pragma mark -  Public

- (NSDate *)date
{
    return [NSDate dateWithTimeIntervalSince1970:self.dateInterval];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"OCTFriendRequest with publicKey %@...\nmessage length %lu",
            [self.publicKey substringToIndex:5], (unsigned long)self.message.length];
}

@end
