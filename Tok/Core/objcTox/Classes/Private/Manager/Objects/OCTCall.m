// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTCall+Utilities.h"
#import "OCTToxAVConstants.h"

@interface OCTCall ()

@end

@implementation OCTCall

- (BOOL)isOutgoing
{
    return (self.caller == nil);
}

- (NSDate *)onHoldDate
{
    if (self.onHoldStartInterval <= 0) {
        return nil;
    }

    return [NSDate dateWithTimeIntervalSince1970:self.onHoldStartInterval];
}

@end
