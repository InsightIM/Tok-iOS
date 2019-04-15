// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFileDataOutput.h"

@interface OCTFileDataOutput ()

@property (strong, nonatomic) NSMutableData *tempData;
@property (strong, nonatomic) NSData *resultData;

@end

@implementation OCTFileDataOutput

#pragma mark -  OCTFileOutputProtocol

- (BOOL)prepareToWrite
{
    self.tempData = [NSMutableData new];
    return YES;
}

- (BOOL)writeData:(nonnull NSData *)data
{
    [self.tempData appendData:data];
    return YES;
}

- (BOOL)finishWriting
{
    self.resultData = [self.tempData copy];
    self.tempData = nil;
    return YES;
}

- (void)cancel
{
    self.tempData = nil;
}

@end
