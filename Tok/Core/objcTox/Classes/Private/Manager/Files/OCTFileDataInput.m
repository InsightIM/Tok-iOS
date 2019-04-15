// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFileDataInput.h"
#import "OCTLogging.h"

@interface OCTFileDataInput ()

@property (strong, nonatomic, readonly) NSData *data;

@end

@implementation OCTFileDataInput

#pragma mark -  Lifecycle

- (nullable instancetype)initWithData:(nonnull NSData *)data
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _data = data;

    return self;
}

#pragma mark -  OCTFileInputProtocol

- (BOOL)prepareToRead
{
    return YES;
}

- (nonnull NSData *)bytesWithPosition:(OCTToxFileSize)position length:(size_t)length
{
    @try {
        return [self.data subdataWithRange:NSMakeRange((NSUInteger)position, length)];
    }
    @catch (NSException *ex) {
        OCTLogWarn(@"catched exception %@", ex);
    }

    return nil;
}

@end
