// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTToxConstants.h"

/**
 * Maximum avatar size as defined in
 * https://tox.gitbooks.io/tox-client-standard/content/user_identification/avatar.html
 */
static const OCTToxFileSize kOCTManagerMaxAvatarSize = 655360;
static const OCTToxFileSize kOCTManagerMaxOfflineFileSize = 10240000; // 10M

typedef NS_ENUM(NSInteger, OCTFetchRequestType) {
    OCTFetchRequestTypeFriend,
    OCTFetchRequestTypeFriendRequest,
    OCTFetchRequestTypeChat,
    OCTFetchRequestTypeCall,
    OCTFetchRequestTypeMessageAbstract,
};

typedef NS_ENUM(NSInteger, OCTMessageFileType) {
    /**
     * File is incoming and is waiting confirmation of user to be downloaded.
     * Please start loading or cancel it with <<placeholder>> method.
     */
    OCTMessageFileTypeWaitingConfirmation,

    /**
     * File is downloading or uploading.
     */
    OCTMessageFileTypeLoading,

    /**
     * Downloading or uploading of file is paused.
     */
    OCTMessageFileTypePaused,

    /**
     * Downloading or uploading of file was canceled.
     */
    OCTMessageFileTypeCanceled,

    /**
     * File is fully loaded.
     * In case of incoming file now it can be shown to user.
     */
    OCTMessageFileTypeReady,
};

typedef NS_ENUM(NSInteger, OCTMessageFilePausedBy) {
    /**
     * File transfer isn't paused.
     */
    OCTMessageFilePausedByNone = 0,

    /**
     * File transfer is paused by user.
     */
    OCTMessageFilePausedByUser = 1 << 0,

        /**
         * File transfer is paused by friend.
         */
        OCTMessageFilePausedByFriend = 1 << 1,
};

typedef NS_ENUM(NSInteger, OCTMessageCallEvent) {
    /**
     * Call was answered.
     */
    OCTMessageCallEventAnswered,

    /**
     * Call was unanswered.
     */
    OCTMessageCallEventUnanswered,
};

typedef NS_ENUM(NSInteger, OCTCallStatus) {
    /**
     * Call is currently ringing.
     */
    OCTCallStatusRinging,

    /**
     * Call is currently dialing a chat.
     */
    OCTCallStatusDialing,

    /**
     * Call is currently active in session.
     */
    OCTCallStatusActive,
};

typedef NS_OPTIONS(NSInteger, OCTCallPausedStatus) {
    /**
     * Call is not paused
     */
    OCTCallPausedStatusNone = 0,

    /**
     * Call is paused by the user
     */
    OCTCallPausedStatusByUser = 1 << 0,

        /**
         * Call is paused by friend
         */
        OCTCallPausedStatusByFriend = 1 << 1,
};

extern NSString *const kOCTManagerErrorDomain;

typedef NS_ENUM(NSInteger, OCTManagerInitError) {
    /**
     * Cannot create symmetric key from given passphrase.
     */
    OCTManagerInitErrorPassphraseFailed,

    /** ---------------------------------------- */

    /**
     * Cannot copy tox save at `importToxSaveFromPath` path.
     */
    OCTManagerInitErrorCannotImportToxSave,

    /** ---------------------------------------- */

    /**
     * Cannot create encryption key.
     */
    OCTManagerInitErrorDatabaseKeyCannotCreateKey,

    /**
     * Cannot read encryption key.
     */
    OCTManagerInitErrorDatabaseKeyCannotReadKey,

    /**
     * Old unencrypted database was found and migration attempt was made. However migration failed for some reason.
     *
     * You can check NSLocalizedDescriptionKey and NSLocalizedFailureReasonErrorKey for more info.
     */
    OCTManagerInitErrorDatabaseKeyMigrationToEncryptedFailed,

    /**
     * Cannot decrypt database key file.
     * Some input data was empty.
     */
    OCTManagerInitErrorDatabaseKeyDecryptNull,

    /**
     * Cannot decrypt database key file.
     * The input data is missing the magic number (i.e. wasn't created by this module, or is corrupted).
     */
    OCTManagerInitErrorDatabaseKeyDecryptBadFormat,

    /**
     * Cannot decrypt database key file.
     * The encrypted byte array could not be decrypted. Either the data was corrupt or the password/key was incorrect.
     */
    OCTManagerInitErrorDatabaseKeyDecryptFailed,

    /** ---------------------------------------- */

    /**
     * Cannot decrypt tox save file.
     * Some input data was empty.
     */
    OCTManagerInitErrorToxFileDecryptNull,

    /**
     * Cannot decrypt tox save file.
     * The input data is missing the magic number (i.e. wasn't created by this module, or is corrupted).
     */
    OCTManagerInitErrorToxFileDecryptBadFormat,

    /**
     * Cannot decrypt tox save file.
     * The encrypted byte array could not be decrypted. Either the data was corrupt or the password/key was incorrect.
     */
    OCTManagerInitErrorToxFileDecryptFailed,

    /** ---------------------------------------- */

    /**
     * Cannot create tox.
     * Unknown error occurred.
     */
    OCTManagerInitErrorCreateToxUnknown,

    /**
     * Cannot create tox.
     * Was unable to allocate enough memory to store the internal structures for the Tox object.
     */
    OCTManagerInitErrorCreateToxMemoryError,

    /**
     * Cannot create tox.
     * Was unable to bind to a port. This may mean that all ports have already been bound,
     * e.g. by other Tox instances, or it may mean a permission error.
     */
    OCTManagerInitErrorCreateToxPortAlloc,

    /**
     * Cannot create tox.
     * proxyType was invalid.
     */
    OCTManagerInitErrorCreateToxProxyBadType,

    /**
     * Cannot create tox.
     * proxyAddress had an invalid format or was nil (while proxyType was set).
     */
    OCTManagerInitErrorCreateToxProxyBadHost,

    /**
     * Cannot create tox.
     * proxyPort was invalid.
     */
    OCTManagerInitErrorCreateToxProxyBadPort,

    /**
     * Cannot create tox.
     * The proxy host passed could not be resolved.
     */
    OCTManagerInitErrorCreateToxProxyNotFound,

    /**
     * Cannot create tox.
     * The saved data to be loaded contained an encrypted save.
     */
    OCTManagerInitErrorCreateToxEncrypted,

    /**
     * Cannot create tox.
     * The data format was invalid. This can happen when loading data that was
     * saved by an older version of Tox, or when the data has been corrupted.
     * When loading from badly formatted data, some data may have been loaded,
     * and the rest is discarded. Passing an invalid length parameter also
     * causes this error.
     */
    OCTManagerInitErrorCreateToxBadFormat,
};

typedef NS_ENUM(NSInteger, OCTSetUserAvatarError) {
    /**
     * User avatar size is too big. It should be <= kOCTManagerMaxAvatarSize.
     */
    OCTSetUserAvatarErrorTooBig,
};

typedef NS_ENUM(NSInteger, OCTSendFileError) {
    /**
     * Internal error occured while sending file.
     * Check logs for more info.
     */
    OCTSendFileErrorInternalError,

    /**
     * Cannot read file.
     */
    OCTSendFileErrorCannotReadFile,

    /**
     * Cannot save send file to uploads folder.
     */
    OCTSendFileErrorCannotSaveFileToUploads,

    /**
     * Friend to send file to was not found.
     */
    OCTSendFileErrorFriendNotFound,

    /**
     * Friend is not connected at the moment.
     */
    OCTSendFileErrorFriendNotConnected,

    /**
     * Filename length exceeded kOCTToxMaxFileNameLength bytes.
     */
    OCTSendFileErrorNameTooLong,

    /**
     * Too many ongoing transfers. The maximum number of concurrent file transfers
     * is 256 per friend per direction (sending and receiving).
     */
    OCTSendFileErrorTooMany,
    
    OCTSendFileErrorOfflineFileTooBig,
};

typedef NS_ENUM(NSInteger, OCTAcceptFileError) {
    /**
     * Internal error occured while sending file.
     * Check logs for more info.
     */
    OCTAcceptFileErrorInternalError,

    /**
     * File is not available for writing.
     */
    OCTAcceptFileErrorCannotWriteToFile,

    /**
     * Friend to send file to was not found.
     */
    OCTAcceptFileErrorFriendNotFound,

    /**
     * Friend is not connected at the moment.
     */
    OCTAcceptFileErrorFriendNotConnected,

    /**
     * Wrong message specified (with no friend, no file or not waiting for confirmation).
     */
    OCTAcceptFileErrorWrongMessage,
};

typedef NS_ENUM(NSInteger, OCTFileTransferError) {
    /**
     * Wrong message specified (with no file).
     */
    OCTFileTransferErrorWrongMessage,
};
