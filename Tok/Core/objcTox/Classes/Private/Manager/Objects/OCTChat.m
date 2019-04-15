// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTChat.h"
#import "OCTMessageAbstract.h"

@interface OCTChat ()

@end

@implementation OCTChat

#pragma mark -  Public

- (NSDate *)lastReadDate
{
    if (self.lastReadDateInterval <= 0) {
        return nil;
    }

    return [NSDate dateWithTimeIntervalSince1970:self.lastReadDateInterval];
}

- (NSDate *)lastActivityDate
{
    if (self.lastActivityDateInterval <= 0) {
        return nil;
    }

    return [NSDate dateWithTimeIntervalSince1970:self.lastActivityDateInterval];
}

- (BOOL)hasUnreadMessages
{
    return (self.lastMessage.dateInterval > self.lastReadDateInterval);
}

@end
