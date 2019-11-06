// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTMessageFile.h"

@interface OCTMessageFile ()

@end

@implementation OCTMessageFile

#pragma mark -  Public

- (nullable NSString *)filePath
{
    return [self.internalFilePath stringByExpandingTildeInPath];
}

- (void)internalSetFilePath:(NSString *)path
{
    self.internalFilePath = [path stringByAbbreviatingWithTildeInPath];
}

- (NSString *)description
{
    NSString *description = [super description];

    const NSUInteger maxSymbols = 3;
    NSString *fileName = self.fileName.length > maxSymbols ? ([self.fileName substringToIndex:maxSymbols]) : @"";

    return [description stringByAppendingFormat:@"OCTMessageFile with fileName = %@..., fileSize = %llu",
            fileName, self.fileSize];
}

@end
