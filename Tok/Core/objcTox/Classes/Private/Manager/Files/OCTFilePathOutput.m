// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFilePathOutput.h"
#import "OCTLogging.h"
#import "OCTFileTools.h"

@interface OCTFilePathOutput ()

@property (copy, nonatomic, readonly, nonnull) NSString *tempFilePath;

@property (strong, nonatomic) NSFileHandle *handle;

@end

@implementation OCTFilePathOutput

#pragma mark -  Lifecycle

- (nullable instancetype)initWithTempFolder:(nonnull NSString *)tempFolder
                               resultFolder:(nonnull NSString *)resultFolder
                                   fileName:(nonnull NSString *)fileName
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _tempFilePath = [OCTFileTools createNewFilePathInDirectory:tempFolder fileName:fileName];
    _resultFilePath = [OCTFileTools createNewFilePathInDirectory:resultFolder fileName:fileName];

    // Create dummy file to reserve fileName.
    [[NSFileManager defaultManager] createFileAtPath:_resultFilePath contents:[NSData data] attributes:nil];

    OCTLogInfo(@"temp path %@", _tempFilePath);
    OCTLogInfo(@"result path %@", _resultFilePath);

    return self;
}

#pragma mark -  OCTFileOutputProtocol

- (BOOL)prepareToWrite
{
    if (! [[NSFileManager defaultManager] createFileAtPath:self.tempFilePath contents:nil attributes:nil]) {
        return NO;
    }

    self.handle = [NSFileHandle fileHandleForWritingAtPath:self.tempFilePath];

    if (! self.handle) {
        return NO;
    }

    return YES;
}

- (BOOL)writeData:(nonnull NSData *)data
{
    @try {
        [self.handle writeData:data];
        return YES;
    }
    @catch (NSException *ex) {
        OCTLogWarn(@"catched exception %@", ex);
    }

    return NO;
}

- (BOOL)finishWriting
{
    @try {
        [self.handle synchronizeFile];
    }
    @catch (NSException *ex) {
        OCTLogWarn(@"catched exception %@", ex);
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Remove dummy file.
    if (! [fileManager removeItemAtPath:self.resultFilePath error:nil]) {
        return NO;
    }

    return [[NSFileManager defaultManager] moveItemAtPath:self.tempFilePath toPath:self.resultFilePath error:nil];
}

- (void)cancel
{
    self.handle = nil;

    [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
}

@end
