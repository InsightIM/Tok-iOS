// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTMessageAbstract.h"
#import "OCTMessageText.h"
#import "OCTMessageFile.h"
#import "OCTMessageCall.h"

@interface OCTMessageAbstract ()

@end

@implementation OCTMessageAbstract

#pragma mark -  Public

- (NSDate *)date
{
    if (self.dateInterval <= 0) {
        return nil;
    }

    return [NSDate dateWithTimeIntervalSince1970:self.dateInterval];
}

- (BOOL)isOutgoing
{
    return (self.senderUniqueIdentifier == nil);
}

- (NSString *)description
{
    NSString *string = nil;

    if (self.messageText) {
        string = [self.messageText description];
    }
    else if (self.messageFile) {
        string = [self.messageFile description];
    }
    else if (self.messageCall) {
        string = [self.messageCall description];
    }

    return [NSString stringWithFormat:@"OCTMessageAbstract with date %@, %@", self.date, string];
}

@end
