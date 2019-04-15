// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTDefaultFileStorage.h"

@interface OCTDefaultFileStorage ()

@property (copy, nonatomic) NSString *saveFileName;
@property (copy, nonatomic) NSString *baseDirectory;
@property (copy, nonatomic) NSString *temporaryDirectory;

@end

@implementation OCTDefaultFileStorage

#pragma mark -  Lifecycle

- (instancetype)initWithBaseDirectory:(NSString *)baseDirectory temporaryDirectory:(NSString *)temporaryDirectory
{
    return [self initWithToxSaveFileName:nil baseDirectory:baseDirectory temporaryDirectory:temporaryDirectory];
}

- (instancetype)initWithToxSaveFileName:(NSString *)saveFileName
                          baseDirectory:(NSString *)baseDirectory
                     temporaryDirectory:(NSString *)temporaryDirectory
{
    self = [super init];

    if (! self) {
        return nil;
    }

    if (! saveFileName) {
        saveFileName = @"save";
    } else {
        NSString *oldFileName = [saveFileName stringByAppendingPathExtension:@"tok"];
        NSString *oldToxFile = [baseDirectory stringByAppendingPathComponent:oldFileName];
        
        // name.tok -> name.tox
        if ([[NSFileManager defaultManager] fileExistsAtPath:oldToxFile]) {
            NSString *fileName = [saveFileName stringByAppendingPathExtension:@"tox"];
            NSString *newFile = [baseDirectory stringByAppendingPathComponent:fileName];
            
            NSError *error;
            BOOL moved = [[NSFileManager defaultManager] copyItemAtPath:oldToxFile toPath:newFile error:&error];
            if (moved && error == nil) {
                [[NSFileManager defaultManager] removeItemAtPath:oldToxFile error:nil];
            }
        } else {
            // save.tox -> name.tox
            NSString *oldFile = [baseDirectory stringByAppendingPathComponent:@"save.tox"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:oldFile]) {
                NSString *fileName = [saveFileName stringByAppendingPathExtension:@"tox"];
                NSString *newFile = [baseDirectory stringByAppendingPathComponent:fileName];
                
                NSError *error;
                BOOL moved = [[NSFileManager defaultManager] copyItemAtPath:oldFile toPath:newFile error:&error];
                if (moved && error == nil) {
                    [[NSFileManager defaultManager] removeItemAtPath:oldFile error:nil];
                }
            }
        }
    }

    self.saveFileName = [saveFileName stringByAppendingPathExtension:@"tox"];
    self.baseDirectory = baseDirectory;
    self.temporaryDirectory = temporaryDirectory;

    return self;
}

#pragma mark -  OCTFileStorageProtocol

- (NSString *)pathForToxSaveFile
{
    return [self.baseDirectory stringByAppendingPathComponent:self.saveFileName];
}

- (NSString *)pathForDatabase
{
    return [self.baseDirectory stringByAppendingPathComponent:@"database"];
}

- (NSString *)pathForDatabaseEncryptionKey
{
    return [self.baseDirectory stringByAppendingPathComponent:@"database.encryptionkey"];
}

- (NSString *)pathForDownloadedFilesDirectory
{
    return [self.baseDirectory stringByAppendingPathComponent:@"files"];
}

- (NSString *)pathForVideoThumbFilesDirectory
{
    return [self.baseDirectory stringByAppendingPathComponent:@"thumbs"];
}

- (NSString *)pathForUploadedFilesDirectory
{
    return [self.baseDirectory stringByAppendingPathComponent:@"files"];
}

- (NSString *)pathForTemporaryFilesDirectory
{
    return self.temporaryDirectory;
}

- (NSString *)pathForAvatarsDirectory
{
    return [self.baseDirectory stringByAppendingPathComponent:@"avatars"];
}

@end
