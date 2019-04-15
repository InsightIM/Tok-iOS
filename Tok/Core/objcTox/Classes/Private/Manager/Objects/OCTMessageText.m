// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTMessageText.h"

@interface OCTMessageText ()

@end

@implementation OCTMessageText

- (NSString *)description
{
    NSString *description = [super description];

    const NSUInteger maxSymbols = 3;
    NSString *text = self.text.length > maxSymbols ? ([self.text substringToIndex:maxSymbols]) : @"";

    return [description stringByAppendingFormat:@"OCTMessageText %@..., length %lu", text, (unsigned long)self.text.length];
}

@end
