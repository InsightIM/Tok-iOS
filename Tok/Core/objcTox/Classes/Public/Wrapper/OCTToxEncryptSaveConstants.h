// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

typedef NS_ENUM(NSInteger, OCTToxEncryptSaveKeyDerivationError) {
    OCTToxEncryptSaveKeyDerivationErrorNone,
    OCTToxEncryptSaveKeyDerivationErrorFailed,
};

typedef NS_ENUM(NSInteger, OCTToxEncryptSaveEncryptionError) {
    OCTToxEncryptSaveEncryptionErrorNone,

    /**
     * Some input data was empty.
     */
    OCTToxEncryptSaveEncryptionErrorNull,

    /**
     * Encryption failed.
     */
    OCTToxEncryptSaveEncryptionErrorFailed,
};

typedef NS_ENUM(NSInteger, OCTToxEncryptSaveDecryptionError) {
    OCTToxEncryptSaveDecryptionErrorNone,

    /**
     * Some input data was empty.
     */
    OCTToxEncryptSaveDecryptionErrorNull,

    /**
     * The input data is missing the magic number (i.e. wasn't created by this module, or is corrupted).
     */
    OCTToxEncryptSaveDecryptionErrorBadFormat,

    /**
     * The encrypted byte array could not be decrypted. Either the data was corrupt or the password/key was incorrect.
     */
    OCTToxEncryptSaveDecryptionErrorFailed,
};
