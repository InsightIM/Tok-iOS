// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTMessageCall.h"

@implementation OCTMessageCall

#pragma mark -  Public

- (NSString *)description
{
    NSString *description = [super description];

    return [description stringByAppendingString:[self typeDescription]];
}

#pragma mark - Private

- (NSString *)typeDescription
{
    NSString *description;
    switch (self.callEvent) {
        case OCTMessageCallEventAnswered:
            description = [[NSString alloc] initWithFormat:@"Call lasted %f seconds", self.callDuration];
            break;
        case OCTMessageCallEventUnanswered:
            description = @"Call unanswered";
            break;
    }
    return description;
}

@end
