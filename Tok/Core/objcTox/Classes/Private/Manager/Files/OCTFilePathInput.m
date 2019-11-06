// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFilePathInput.h"
#import "OCTLogging.h"

@interface OCTFilePathInput ()

@property (strong, nonatomic, readonly) NSString *filePath;
@property (strong, nonatomic) NSFileHandle *handle;

@end

@implementation OCTFilePathInput

#pragma mark -  Lifecycle

- (nullable instancetype)initWithFilePath:(nonnull NSString *)filePath
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _filePath = filePath;

    return self;
}

#pragma mark -  OCTFileInputProtocol

- (BOOL)prepareToRead
{
    self.handle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];

    if (! self.handle) {
        return NO;
    }

    return YES;
}

- (NSData *)bytesWithPosition:(OCTToxFileSize)position length:(size_t)length
{
    @try {
        if (self.handle.offsetInFile != position) {
            [self.handle seekToFileOffset:position];
        }

        return [self.handle readDataOfLength:length];
    }
    @catch (NSException *ex) {
        OCTLogWarn(@"catched exception %@", ex);
    }

    return nil;
}

@end
