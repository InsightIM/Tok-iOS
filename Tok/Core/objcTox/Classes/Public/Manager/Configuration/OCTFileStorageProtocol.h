// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol OCTFileStorageProtocol <NSObject>

@required

/**
 * Returns path where tox save data will be stored. Save file should have ".tox" extension.
 * See Tox STS for more information: https://github.com/Tox/Tox-STS
 *
 * @return Full path to the file for loading/saving tox data.
 *
 * @warning Path should be file path. The file can be rewritten at any time while OCTManager is alive.
 */
@property (readonly) NSString *pathForToxSaveFile;

/**
 * Returns file path for database to be stored in. Must be a file path, not directory.
 * In database will be stored chats, messages and related stuff.
 *
 * @return Full path to the file for the database.
 *
 * @warning Path should be file path. The file can be rewritten at any time while OCTManager is alive.
 */
@property (readonly) NSString *pathForDatabase;

/**
 * Returns file path for database encryption key to be stored in. Must be a file path, not a directory.
 *
 * @return Full path to the file to store database encryption key.
 *
 * @warning Path should be file path. The file can be rewritten at any time while OCTManager is alive.
 */
@property (readonly) NSString *pathForDatabaseEncryptionKey;

/**
 * Returns path where all downloaded files will be stored.
 *
 * @return Full path to the directory with downloaded files.
 */
@property (readonly) NSString *pathForDownloadedFilesDirectory;

/**
 * Returns path where all video thumbnails will be stored.
 *
 * @return Full path to the directory with video thumbnails.
 */
@property (readonly) NSString *pathForVideoThumbFilesDirectory;

/**
 * Returns path where all uploaded files will be stored.
 *
 * @return Full path to the directory with uploaded files.
 */
@property (readonly) NSString *pathForUploadedFilesDirectory;

/**
 * Returns path where temporary files will be stored. This directory can be cleaned on relaunch of app.
 * You can use NSTemporaryDirectory() here.
 *
 * @return Full path to the directory with temporary files.
 */
@property (readonly) NSString *pathForTemporaryFilesDirectory;

/**
 * Returns path where all avatars will be stored.
 *
 * @return Full path to the directory with avatars.
 */
@property (readonly) NSString *pathForAvatarsDirectory;

@end

NS_ASSUME_NONNULL_END
