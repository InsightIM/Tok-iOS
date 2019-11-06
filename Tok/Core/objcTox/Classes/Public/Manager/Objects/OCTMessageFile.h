// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTObject.h"
#import "OCTToxConstants.h"
#import "OCTManagerConstants.h"

/**
 * Message that contains file, that has been send/received. Represents pending, canceled and loaded files.
 *
 * Please note that all properties of this object are readonly.
 * You can change some of them only with appropriate method in OCTSubmanagerObjects.
 */
@interface OCTMessageFile : OCTObject

/* bot message check exist */
@property OCTToxMessageId messageId;

@property BOOL isOffline;

@property BOOL expired;

@property BOOL opened;

@property (nullable) NSString * duration;

/**
 * The current state of file.
 */
@property OCTMessageFileType fileType;

/**
 * In case if fileType is equal to OCTMessageFileTypePaused this property will contain information
 * by whom file transfer was paused.
 */
@property OCTMessageFilePausedBy pausedBy;

/**
 * Size of file in bytes.
 */
@property OCTToxFileSize fileSize;

/**
 * Name of the file as specified by sender. Note that actual fileName in path
 * may differ from this fileName.
 */
@property (nullable) NSString *fileName;

/**
 * Uniform Type Identifier of file.
 */
@property (nullable) NSString *fileUTI;

/**
 * Path of file on disk. If you need fileName to show to user please use
 * `fileName` property. filePath has it's own random fileName.
 *
 * In case of incoming file filePath will have value only if fileType is OCTMessageFileTypeReady
 */
- (nullable NSString *)filePath;

// Properties and methods below are for internal use.
// Do not use them or rely on them. They may change in any moment.

@property int internalFileNumber;
@property (nullable) NSString *internalFilePath;
- (void)internalSetFilePath:(nullable NSString *)path;

@end

RLM_ARRAY_TYPE(OCTMessageFile)
