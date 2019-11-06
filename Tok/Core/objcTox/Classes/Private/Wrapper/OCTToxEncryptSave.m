// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTToxEncryptSave.h"
#import "toxencryptsave.h"
#import "OCTToxEncryptSaveConstants.h"
#import "OCTTox+Private.h"

@interface OCTToxEncryptSave ()

@property (assign, nonatomic) Tox_Pass_Key *passKey;

@end

@implementation OCTToxEncryptSave

#pragma mark -  Lifecycle

- (nullable instancetype)initWithPassphrase:(nonnull NSString *)passphrase
                                    toxData:(nullable NSData *)toxData
                                      error:(NSError *__nullable *__nullable)error
{
    self = [super init];

    if (! self) {
        return nil;
    }

    TOX_ERR_KEY_DERIVATION cError;

    uint8_t salt[TOX_PASS_SALT_LENGTH];
    bool hasSalt = false;

    if (toxData) {
        hasSalt = tox_get_salt(toxData.bytes, salt, NULL);
    }

    if (hasSalt) {
        _passKey = tox_pass_key_derive_with_salt(
            (const uint8_t *)[passphrase cStringUsingEncoding:NSUTF8StringEncoding],
            [passphrase lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
            salt,
            &cError);
    }
    else {
        _passKey = tox_pass_key_derive(
            (const uint8_t *)[passphrase cStringUsingEncoding:NSUTF8StringEncoding],
            [passphrase lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
            &cError);
    }

    [OCTToxEncryptSave fillError:error withCErrorKeyDerivation:cError];

    return (_passKey != NULL) ? self : nil;
}

- (void)dealloc
{
    if (_passKey) {
        tox_pass_key_free(_passKey);
    }
}

#pragma mark -  Public class methods

+ (BOOL)isDataEncrypted:(nonnull NSData *)data
{
    return tox_is_data_encrypted(data.bytes);
}

+ (nullable NSData *)encryptData:(nonnull NSData *)data
                  withPassphrase:(nonnull NSString *)passphrase
                           error:(NSError *__nullable *__nullable)error
{
    NSParameterAssert(data);
    NSParameterAssert(passphrase);

    return [OCTToxEncryptSave convertDataOfLength:data.length encrypt:YES withConvertBlock:^bool (uint8_t *out) {
        TOX_ERR_ENCRYPTION cError;

        bool result = tox_pass_encrypt(
            data.bytes,
            data.length,
            (const uint8_t *)[passphrase cStringUsingEncoding:NSUTF8StringEncoding],
            [passphrase lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
            out,
            &cError);

        [OCTToxEncryptSave fillError:error withCErrorEncryption:cError];

        return result;
    }];
}

+ (nullable NSData *)decryptData:(nonnull NSData *)data
                  withPassphrase:(nonnull NSString *)passphrase
                           error:(NSError *__nullable *__nullable)error
{
    NSParameterAssert(data);
    NSParameterAssert(passphrase);

    return [OCTToxEncryptSave convertDataOfLength:data.length encrypt:NO withConvertBlock:^bool (uint8_t *out) {
        TOX_ERR_DECRYPTION cError;

        bool result = tox_pass_decrypt(
            data.bytes,
            data.length,
            (const uint8_t *)[passphrase cStringUsingEncoding:NSUTF8StringEncoding],
            [passphrase lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
            out,
            &cError);

        [OCTToxEncryptSave fillError:error withCErrorDecryption:cError];

        return result;
    }];
}

#pragma mark -  Public instance method

- (nullable NSData *)encryptData:(nonnull NSData *)data error:(NSError *__nullable *__nullable)error
{
    NSParameterAssert(data);

    return [OCTToxEncryptSave convertDataOfLength:data.length encrypt:YES withConvertBlock:^bool (uint8_t *out) {
        TOX_ERR_ENCRYPTION cError;

        bool result = tox_pass_key_encrypt(
            self.passKey,
            data.bytes,
            data.length,
            out,
            &cError);

        [OCTToxEncryptSave fillError:error withCErrorEncryption:cError];

        return result;
    }];
}

- (nullable NSData *)decryptData:(nonnull NSData *)data error:(NSError *__nullable *__nullable)error
{
    NSParameterAssert(data);

    return [OCTToxEncryptSave convertDataOfLength:data.length encrypt:NO withConvertBlock:^bool (uint8_t *out) {
        TOX_ERR_DECRYPTION cError;

        bool result = tox_pass_key_decrypt(
            self.passKey,
            data.bytes,
            data.length,
            out,
            &cError);

        [OCTToxEncryptSave fillError:error withCErrorDecryption:cError];

        return result;
    }];
}

#pragma mark -  Private

+ (NSData *)convertDataOfLength:(NSUInteger)dataLength
                        encrypt:(BOOL)encrypt
               withConvertBlock:(bool (^)(uint8_t *out))convertBlock
{
    NSUInteger outLength = dataLength + (encrypt ? TOX_PASS_ENCRYPTION_EXTRA_LENGTH : -TOX_PASS_ENCRYPTION_EXTRA_LENGTH);
    uint8_t *out = malloc(outLength);

    bool result = convertBlock(out);
    NSData *resultData = nil;

    if (result) {
        resultData = [NSData dataWithBytes:out length:outLength];
    }

    if (out) {
        free(out);
    }

    return resultData;
}

+ (BOOL)fillError:(NSError **)error withCErrorKeyDerivation:(TOX_ERR_KEY_DERIVATION)cError
{
    if (! error || (cError == TOX_ERR_KEY_DERIVATION_OK)) {
        return NO;
    }

    switch (cError) {
        case TOX_ERR_KEY_DERIVATION_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_KEY_DERIVATION_NULL:
        case TOX_ERR_KEY_DERIVATION_FAILED:
            *error = [OCTTox createErrorWithCode:OCTToxEncryptSaveKeyDerivationErrorFailed
                                     description:@"Cannot create key from given passphrase"
                                   failureReason:nil];
            break;
    }


    return YES;
}

+ (BOOL)fillError:(NSError **)error withCErrorEncryption:(TOX_ERR_ENCRYPTION)cError
{
    if (! error || (cError == TOX_ERR_ENCRYPTION_OK)) {
        return NO;
    }

    OCTToxEncryptSaveEncryptionError code;
    NSString *description = @"Encryption failed";
    NSString *failureReason = nil;

    switch (cError) {
        case TOX_ERR_ENCRYPTION_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_ENCRYPTION_NULL:
            code = OCTToxEncryptSaveEncryptionErrorNull;
            failureReason = @"Some input data was empty.";
            break;
        case TOX_ERR_ENCRYPTION_KEY_DERIVATION_FAILED:
        case TOX_ERR_ENCRYPTION_FAILED:
            code = OCTToxEncryptSaveEncryptionErrorFailed;
            failureReason = @"Encryption failed, please report";
            break;
    }

    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

+ (BOOL)fillError:(NSError **)error withCErrorDecryption:(TOX_ERR_DECRYPTION)cError
{
    if (! error || (cError == TOX_ERR_DECRYPTION_OK)) {
        return NO;
    }

    OCTToxEncryptSaveDecryptionError code;
    NSString *description = @"Decryption failed";
    NSString *failureReason = nil;

    switch (cError) {
        case TOX_ERR_DECRYPTION_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_DECRYPTION_NULL:
            code = OCTToxEncryptSaveDecryptionErrorNull;
            failureReason = @"Some input data was empty.";
            break;
        case TOX_ERR_DECRYPTION_BAD_FORMAT:
            code = OCTToxEncryptSaveDecryptionErrorBadFormat;
            failureReason = @"The input data has bad format";
            break;
        case TOX_ERR_DECRYPTION_INVALID_LENGTH:
        case TOX_ERR_DECRYPTION_KEY_DERIVATION_FAILED:
        case TOX_ERR_DECRYPTION_FAILED:
            code = OCTToxEncryptSaveDecryptionErrorFailed;
            failureReason = @"Decryption failed, passphrase is incorrect or data is corrupt";
            break;
    }

    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];

    return YES;
}

@end
