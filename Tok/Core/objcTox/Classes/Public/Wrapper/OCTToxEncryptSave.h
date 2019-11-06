// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

/**
 * This class is used for encryption/decryption of save data.
 *
 * You can use class methods or create instance and use it's methods.
 * Note that instance encryption/decryption methods are much faster because
 * instance stores generated encryption key.
 */
@interface OCTToxEncryptSave : NSObject

/**
 * Determines whether or not the given data is encrypted (by checking the magic number).
 *
 * @param data Data to check.
 *
 * @return YES if data is encrypted, NO otherwise.
 */
+ (BOOL)isDataEncrypted:(nonnull NSData *)data;

/**
 * Encrypts the given data with the given passphrase.
 *
 * @param data Data to encrypt.
 * @param passphrase Passphrase used to encrypt the data.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxEncryptSaveEncryptionError for all error codes.
 *
 * @return Encrypted data on success, nil on failure.
 */
+ (nullable NSData *)encryptData:(nonnull NSData *)data
                  withPassphrase:(nonnull NSString *)passphrase
                           error:(NSError *__nullable *__nullable)error;

/**
 * Decrypts the given data with the given passphrase.
 *
 * @param data Data to decrypt.
 * @param passphrase Passphrase used to decrypt the data.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxEncryptSaveDecryptionError for all error codes.
 *
 * @return Decrypted data on success, nil on failure.
 */
+ (nullable NSData *)decryptData:(nonnull NSData *)data
                  withPassphrase:(nonnull NSString *)passphrase
                           error:(NSError *__nullable *__nullable)error;

/**
 * Creates new instance of OCTToxEncryptSave object with given passphrase. This instance can be used
 * to encrypt and decrypt given data.
 * Encryption key is generated and stored in this method. Due to that encrypting/decrypting data
 * using instance instead of class methods is much faster, as key derivation is very expensive compared
 * to the actual encryption.
 *
 * @param passphrase Passphrase used to encrypt/decrypt the data.
 * @param toxData If you have toxData that you would like to decrypt, you have to pass it here. Salt will be extracted from data and used for key generation.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxEncryptSaveKeyDerivationError for all error codes.
 *
 * @return Created instance or nil in case of error.
 */
- (nullable instancetype)initWithPassphrase:(nonnull NSString *)passphrase
                                    toxData:(nullable NSData *)toxData
                                      error:(NSError *__nullable *__nullable)error;

/**
 * Encrypts the given data.
 *
 * @param data Data to encrypt.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxEncryptSaveEncryptionError for all error codes.
 *
 * @return Encrypted data on success, nil on failure.
 */
- (nullable NSData *)encryptData:(nonnull NSData *)data error:(NSError *__nullable *__nullable)error;

/**
 * Decrypts the given data.
 *
 * @param data Data to decrypt.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxEncryptSaveDecryptionError for all error codes.
 *
 * @return Decrypted data on success, nil on failure.
 */
- (nullable NSData *)decryptData:(nonnull NSData *)data error:(NSError *__nullable *__nullable)error;

@end
