// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

#import "OCTFileStorageProtocol.h"

/**
 * Default storage for files. It has following directory structure:
 * /baseDirectory/saveFileName.tox       - tox save file name. You can specify it in appropriate method.
 * /baseDirectory/database               - database with chats, messages and related stuff.
 * /baseDirectory/database.encryptionkey - encryption key for database.
 * /baseDirectory/files/                 - downloaded and uploaded files will be stored here.
 * /baseDirectory/avatars/               - avatars will be stored here.
 * /temporaryDirectory/                  - temporary files will be stored here.
 */
@interface OCTDefaultFileStorage : NSObject <OCTFileStorageProtocol>

/**
 * Creates default file storage. Will use "save.tox" as default save file name.
 *
 * @param baseDirectory Base directory to use. It will have "files", "avatars" subdirectories.
 * @param temporaryDirectory All temporary files will be stored here. You can pass NSTemporaryDirectory() here.
 */
- (instancetype)initWithBaseDirectory:(NSString *)baseDirectory temporaryDirectory:(NSString *)temporaryDirectory;

/**
 * Creates default file storage.
 *
 * @param saveFileName Name of file to store tox save data. ".tox" extension will be appended to the name.
 * @param baseDirectory Base directory to use. It will have "files", "avatars" subdirectories.
 * @param temporaryDirectory All temporary files will be stored here. You can pass NSTemporaryDirectory() here.
 */
- (instancetype)initWithToxSaveFileName:(NSString *)saveFileName
                          baseDirectory:(NSString *)baseDirectory
                     temporaryDirectory:(NSString *)temporaryDirectory;

@end
