// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTManagerFactory.h"
#import "OCTManagerImpl.h"
#import "OCTManagerConfiguration.h"
#import "OCTRealmManager.h"
#import "OCTTox.h"
#import "OCTToxEncryptSave.h"
#import "OCTToxEncryptSaveConstants.h"

typedef NS_ENUM(NSInteger, OCTDecryptionErrorFileType) {
    OCTDecryptionErrorFileTypeDatabaseKey,
    OCTDecryptionErrorFileTypeToxFile,
};

static const NSUInteger kEncryptedKeyLength = 64;

@implementation OCTManagerFactory

#if DEBUG
+ (NSString *)hexadecimalString:(NSData *)data {
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    if (!dataBuffer) return [NSString string];
    
    NSUInteger          dataLength  = [data length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return [NSString stringWithString:hexString];
}
#endif

+ (void)managerWithConfiguration:(OCTManagerConfiguration *)configuration
                 encryptPassword:(nonnull NSString *)encryptPassword
                   dhtArrayBlock:(NSArray <NSDictionary <NSString *, id>*>*(^)(OCTTox *tox))dhtArrayBlock
                        delegate:(id<OCTToxDelegate>)delegate
                    successBlock:(void (^)(id<OCTManager> manager))successBlock
                    failureBlock:(void (^)(NSError *error))failureBlock
{
    [self validateConfiguration:configuration];

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();

    // Decrypting Realm.
    __block NSData *realmEncryptionKey = nil;
    __block NSError *decryptRealmError = nil;

    dispatch_group_async(group, queue, ^{
        realmEncryptionKey = [self realmEncryptionKeyWithConfiguration:configuration
                                                              password:encryptPassword
                                                                 error:&decryptRealmError];
        #if DEBUG
        NSString *hex = [OCTManagerFactory hexadecimalString:realmEncryptionKey];
        NSLog(@"Realm Encryption Key:\n%@", hex);
        #endif
    });


    // Decrypting Tox save.
    __block NSError *decryptToxError = nil;
    __block OCTToxEncryptSave *encryptSave = nil;
    __block NSData *toxSave = nil;

    dispatch_group_async(group, queue, ^{
        if (! [self importToxSaveIfNeeded:configuration error:&decryptToxError]) {
            return;
        }

        NSData *savedData = [self getSavedDataFromPath:configuration.fileStorage.pathForToxSaveFile];

        encryptSave = [self toxEncryptSaveWithToxPassword:encryptPassword savedData:savedData error:&decryptToxError];

        if (! encryptSave) {
            return;
        }

        savedData = [self decryptSavedData:savedData encryptSave:encryptSave error:&decryptToxError];

        if (! savedData) {
            return;
        }

        toxSave = savedData;
    });

    dispatch_async(queue, ^{
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = decryptRealmError ?: decryptToxError;

            if (error) {
                if (failureBlock) {
                    failureBlock(error);
                }
                return;
            }

            OCTTox *tox = [self createToxWithOptions:configuration.options toxData:toxSave error:&error];
            tox.dhtArray = dhtArrayBlock(tox);

            if (! tox) {
                if (failureBlock) {
                    failureBlock(error);
                }
                return;
            }

            NSURL *databaseFileURL = [NSURL fileURLWithPath:configuration.fileStorage.pathForDatabase];
            OCTRealmManager *realmManager = [[OCTRealmManager alloc] initWithDatabaseFileURL:databaseFileURL encryptionKey:realmEncryptionKey];

            OCTManagerImpl *manager = [[OCTManagerImpl alloc] initWithConfiguration:configuration
                                                                                tox:tox
                                                                     toxEncryptSave:encryptSave
                                                                       realmManager:realmManager
                                                                           delegate:delegate];

            if (successBlock) {
                successBlock(manager);
            }
        });
    });
}

+ (void)buildWithConfiguration:(OCTManagerConfiguration *)configuration
                 encryptPassword:(nonnull NSString *)encryptPassword
                    successBlock:(void (^)(NSDictionary *result))successBlock
                    failureBlock:(void (^)(NSError *error))failureBlock
{
    [self validateConfiguration:configuration];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    
    // Decrypting Realm.
    __block NSData *realmEncryptionKey = nil;
    __block NSError *decryptRealmError = nil;
    
    dispatch_group_async(group, queue, ^{
        realmEncryptionKey = [self realmEncryptionKeyWithConfiguration:configuration
                                                              password:encryptPassword
                                                                 error:&decryptRealmError];
#if DEBUG
        NSString *hex = [OCTManagerFactory hexadecimalString:realmEncryptionKey];
        NSLog(@"Realm Encryption Key:\n%@", hex);
#endif
    });
    
    
    // Decrypting Tox save.
    __block NSError *decryptToxError = nil;
    __block OCTToxEncryptSave *encryptSave = nil;
    __block NSData *toxSave = nil;
    
    dispatch_group_async(group, queue, ^{
        if (! [self importToxSaveIfNeeded:configuration error:&decryptToxError]) {
            return;
        }
        
        NSData *savedData = [self getSavedDataFromPath:configuration.fileStorage.pathForToxSaveFile];
        
        encryptSave = [self toxEncryptSaveWithToxPassword:encryptPassword savedData:savedData error:&decryptToxError];
        
        if (! encryptSave) {
            return;
        }
        
        savedData = [self decryptSavedData:savedData encryptSave:encryptSave error:&decryptToxError];
        
        if (! savedData) {
            return;
        }
        
        toxSave = savedData;
    });
    
    dispatch_async(queue, ^{
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = decryptRealmError ?: decryptToxError;
            
            if (error) {
                if (failureBlock) {
                    failureBlock(error);
                }
                return;
            }
            
            OCTTox *tox = [self createToxWithOptions:configuration.options toxData:toxSave error:&error];
            
            if (! tox) {
                if (failureBlock) {
                    failureBlock(error);
                }
                return;
            }
            
            NSURL *databaseFileURL = [NSURL fileURLWithPath:configuration.fileStorage.pathForDatabase];
            OCTRealmManager *realmManager = [[OCTRealmManager alloc] initWithDatabaseFileURL:databaseFileURL encryptionKey:realmEncryptionKey];
            
            NSDictionary *result = @{
                                     @"database": realmManager,
                                     @"tox": tox,
                                     @"encryptSave": encryptSave,
                                     @"configuration": configuration
                                     };
            if (successBlock) {
                successBlock(result);
            }
        });
    });
}

#pragma mark -  Private

+ (void)validateConfiguration:(OCTManagerConfiguration *)configuration
{
    NSParameterAssert(configuration.fileStorage);
    NSParameterAssert(configuration.fileStorage.pathForDownloadedFilesDirectory);
    NSParameterAssert(configuration.fileStorage.pathForUploadedFilesDirectory);
    NSParameterAssert(configuration.fileStorage.pathForTemporaryFilesDirectory);

    NSParameterAssert(configuration.options);
}

+ (NSData *)realmEncryptionKeyWithConfiguration:(OCTManagerConfiguration *)configuration
                                       password:(NSString *)databasePassword
                                          error:(NSError **)error
{
    NSString *databasePath = configuration.fileStorage.pathForDatabase;
    NSString *encryptedKeyPath = configuration.fileStorage.pathForDatabaseEncryptionKey;

    BOOL databaseExists = [[NSFileManager defaultManager] fileExistsAtPath:databasePath];
    BOOL encryptedKeyExists = [[NSFileManager defaultManager] fileExistsAtPath:encryptedKeyPath];

    if (! databaseExists && ! encryptedKeyExists) {
        // First run, create key and database.
        if (! [self createEncryptedKeyAtPath:encryptedKeyPath withPassword:databasePassword]) {
            [self fillError:error withInitErrorCode:OCTManagerInitErrorDatabaseKeyCannotCreateKey];
            return nil;
        }
    }

    if (databaseExists && ! encryptedKeyExists) {
        // It seems that we found old unencrypted database, let's migrate to encrypted one.
        NSError *migrationError;

        BOOL result = [self migrateToEncryptedDatabase:databasePath
                                     encryptionKeyPath:encryptedKeyPath
                                          withPassword:databasePassword
                                                 error:&migrationError];

        if (! result) {
            if (error) {
                *error = [NSError errorWithDomain:kOCTManagerErrorDomain code:OCTManagerInitErrorDatabaseKeyMigrationToEncryptedFailed userInfo:@{
                              NSLocalizedDescriptionKey : migrationError.localizedDescription,
                              NSLocalizedFailureReasonErrorKey : migrationError.localizedFailureReason,
                          }];
            }

            return nil;
        }
    }

    NSData *encryptedKey = [NSData dataWithContentsOfFile:encryptedKeyPath];

    if (! encryptedKey) {
        [self fillError:error withInitErrorCode:OCTManagerInitErrorDatabaseKeyCannotReadKey];
        return nil;
    }

    NSError *decryptError;
    NSData *key = [OCTToxEncryptSave decryptData:encryptedKey withPassphrase:databasePassword error:&decryptError];

    if (! key) {
        [self fillError:error withDecryptionError:decryptError.code fileType:OCTDecryptionErrorFileTypeDatabaseKey];
        return nil;
    }

    return key;
}

+ (BOOL)createEncryptedKeyAtPath:(NSString *)path withPassword:(NSString *)password
{
    NSMutableData *key = [NSMutableData dataWithLength:kEncryptedKeyLength];
    (void)SecRandomCopyBytes(kSecRandomDefault, key.length, (uint8_t *)key.mutableBytes);

    NSData *encryptedKey = [OCTToxEncryptSave encryptData:key withPassphrase:password error:nil];

    return [encryptedKey writeToFile:path options:NSDataWritingAtomic error:nil];
}

+ (BOOL)fillError:(NSError **)error withDecryptionError:(OCTToxEncryptSaveDecryptionError)code fileType:(OCTDecryptionErrorFileType)fileType
{
    if (! error) {
        return NO;
    }

    NSDictionary *mapping;

    switch (fileType) {
        case OCTDecryptionErrorFileTypeDatabaseKey:
            mapping = @{
                @(OCTToxEncryptSaveDecryptionErrorNull) : @(OCTManagerInitErrorDatabaseKeyDecryptNull),
                @(OCTToxEncryptSaveDecryptionErrorBadFormat) : @(OCTManagerInitErrorDatabaseKeyDecryptBadFormat),
                @(OCTToxEncryptSaveDecryptionErrorFailed) : @(OCTManagerInitErrorDatabaseKeyDecryptFailed),
            };
            break;
        case OCTDecryptionErrorFileTypeToxFile:
            mapping = @{
                @(OCTToxEncryptSaveDecryptionErrorNull) : @(OCTManagerInitErrorToxFileDecryptNull),
                @(OCTToxEncryptSaveDecryptionErrorBadFormat) : @(OCTManagerInitErrorToxFileDecryptBadFormat),
                @(OCTToxEncryptSaveDecryptionErrorFailed) : @(OCTManagerInitErrorToxFileDecryptFailed),
            };
            break;
    }

    OCTManagerInitError initErrorCode = [mapping[@(code)] integerValue];
    [self fillError:error withInitErrorCode:initErrorCode];

    return YES;
}

+ (BOOL)fillError:(NSError **)error withInitErrorCode:(OCTManagerInitError)code
{
    if (! error) {
        return NO;
    }

    NSString *failureReason = nil;

    switch (code) {
        case OCTManagerInitErrorPassphraseFailed:
            failureReason = @"Cannot create symmetric key from given passphrase.";
            break;
        case OCTManagerInitErrorCannotImportToxSave:
            failureReason = @"Cannot copy tok save at `importToxSaveFromPath` path.";
            break;
        case OCTManagerInitErrorDatabaseKeyCannotCreateKey:
            failureReason = @"Cannot create encryption key.";
            break;
        case OCTManagerInitErrorDatabaseKeyCannotReadKey:
            failureReason = @"Cannot read encryption key.";
            break;
        case OCTManagerInitErrorDatabaseKeyMigrationToEncryptedFailed:
            // Nothing to do here, this error will be created elsewhere.
            break;
        case OCTManagerInitErrorDatabaseKeyDecryptNull:
            failureReason = @"Cannot decrypt database key file. Some input data was empty.";
            break;
        case OCTManagerInitErrorDatabaseKeyDecryptBadFormat:
            failureReason = @"Cannot decrypt database key file. Data has bad format.";
            break;
        case OCTManagerInitErrorDatabaseKeyDecryptFailed:
            failureReason = @"Cannot decrypt database key file. The encrypted byte array could not be decrypted. Either the data was corrupt or the password/key was incorrect.";
            break;
        case OCTManagerInitErrorToxFileDecryptNull:
            failureReason = @"Cannot decrypt tok save file. Some input data was empty.";
            break;
        case OCTManagerInitErrorToxFileDecryptBadFormat:
            failureReason = @"Cannot decrypt tok save file. Data has bad format.";
            break;
        case OCTManagerInitErrorToxFileDecryptFailed:
            failureReason = @"Cannot decrypt tok save file. The encrypted byte array could not be decrypted. Either the data was corrupt or the password/key was incorrect.";
            break;
        case OCTManagerInitErrorCreateToxUnknown:
            failureReason = @"Cannot create tok. Unknown error occurred.";
            break;
        case OCTManagerInitErrorCreateToxMemoryError:
            failureReason = @"Cannot create tox. Was unable to allocate enough memory to store the internal structures for the Tok object.";
            break;
        case OCTManagerInitErrorCreateToxPortAlloc:
            failureReason = @"Cannot create tox. Was unable to bind to a port.";
            break;
        case OCTManagerInitErrorCreateToxProxyBadType:
            failureReason = @"Cannot create tox. Proxy type was invalid.";
            break;
        case OCTManagerInitErrorCreateToxProxyBadHost:
            failureReason = @"Cannot create tox. proxyAddress had an invalid format or was nil (while proxyType was set).";
            break;
        case OCTManagerInitErrorCreateToxProxyBadPort:
            failureReason = @"Cannot create tox. Proxy port was invalid.";
            break;
        case OCTManagerInitErrorCreateToxProxyNotFound:
            failureReason = @"Cannot create tox. The proxy host passed could not be resolved.";
            break;
        case OCTManagerInitErrorCreateToxEncrypted:
            failureReason = @"Cannot create tox. The saved data to be loaded contained an encrypted save.";
            break;
        case OCTManagerInitErrorCreateToxBadFormat:
            failureReason = @"Cannot create tox. Data has bad format.";
            break;
    }

    *error = [NSError errorWithDomain:kOCTManagerErrorDomain code:code userInfo:@{
                  NSLocalizedDescriptionKey :failureReason,
                  NSLocalizedFailureReasonErrorKey : failureReason
              }];

    return YES;
}

+ (BOOL)migrateToEncryptedDatabase:(NSString *)databasePath
                 encryptionKeyPath:(NSString *)encryptionKeyPath
                      withPassword:(NSString *)password
                             error:(NSError **)error
{
    NSParameterAssert(databasePath);
    NSParameterAssert(encryptionKeyPath);
    NSParameterAssert(password);

    if ([[NSFileManager defaultManager] fileExistsAtPath:encryptionKeyPath]) {
        if (error) {
            *error = [NSError errorWithDomain:kOCTManagerErrorDomain code:100 userInfo:@{
                          NSLocalizedDescriptionKey : @"Cannot migrate unencrypted database to encrypted",
                          NSLocalizedFailureReasonErrorKey : @"Database is already encrypted",
                      }];
        }
        return NO;
    }

    NSString *tempKeyPath = [encryptionKeyPath stringByAppendingPathExtension:@"tmp"];

    if (! [self createEncryptedKeyAtPath:tempKeyPath withPassword:password]) {
        if (error) {
            *error = [NSError errorWithDomain:kOCTManagerErrorDomain code:101 userInfo:@{
                          NSLocalizedDescriptionKey : @"Cannot migrate unencrypted database to encrypted",
                          NSLocalizedFailureReasonErrorKey : @"Cannot create encryption key",
                      }];
        }
        return NO;
    }

    NSData *encryptedKey = [NSData dataWithContentsOfFile:tempKeyPath];

    if (! encryptedKey) {
        if (error) {
            *error = [NSError errorWithDomain:kOCTManagerErrorDomain code:102 userInfo:@{
                          NSLocalizedDescriptionKey : @"Cannot migrate unencrypted database to encrypted",
                          NSLocalizedFailureReasonErrorKey : @"Cannot find encryption key",
                      }];
        }
        return NO;
    }

    NSData *key = [OCTToxEncryptSave decryptData:encryptedKey withPassphrase:password error:error];

    if (! key) {
        return NO;
    }

    if (! [OCTRealmManager migrateToEncryptedDatabase:databasePath encryptionKey:key error:error]) {
        return NO;
    }

    if (! [[NSFileManager defaultManager] moveItemAtPath:tempKeyPath toPath:encryptionKeyPath error:error]) {
        return NO;
    }

    return YES;
}

+ (BOOL)importToxSaveIfNeeded:(OCTManagerConfiguration *)configuration error:(NSError **)error
{
    BOOL result = YES;

    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (configuration.importToxSaveFromPath && [fileManager fileExistsAtPath:configuration.importToxSaveFromPath]) {
        result = [fileManager copyItemAtPath:configuration.importToxSaveFromPath
                                      toPath:configuration.fileStorage.pathForToxSaveFile
                                       error:nil];
    }

    if (! result) {
        [self fillError:error withInitErrorCode:OCTManagerInitErrorCannotImportToxSave];
    }

    return result;
}

+ (OCTToxEncryptSave *)toxEncryptSaveWithToxPassword:(NSString *)toxPassword
                                           savedData:(NSData *)savedData
                                               error:(NSError **)error
{
    OCTToxEncryptSave *encryptSave;

    if (savedData && [OCTToxEncryptSave isDataEncrypted:savedData]) {
        encryptSave = [[OCTToxEncryptSave alloc] initWithPassphrase:toxPassword toxData:savedData error:nil];
    }
    else {
        // Save data wasn't encrypted. Passing nil as toxData parameter to encrypt it next time.
        encryptSave = [[OCTToxEncryptSave alloc] initWithPassphrase:toxPassword toxData:nil error:nil];
    }

    if (! encryptSave) {
        [self fillError:error withInitErrorCode:OCTManagerInitErrorPassphraseFailed];
        return nil;
    }

    return encryptSave;
}

+ (NSData *)decryptSavedData:(NSData *)data encryptSave:(OCTToxEncryptSave *)encryptSave error:(NSError **)error
{
    NSParameterAssert(encryptSave);

    if (! data) {
        return data;
    }

    if (! [OCTToxEncryptSave isDataEncrypted:data]) {
        // Tox data wasn't encrypted, nothing to do here.
        return data;
    }

    NSError *decryptError = nil;

    NSData *result = [encryptSave decryptData:data error:&decryptError];

    if (result) {
        return result;
    }

    [self fillError:error withDecryptionError:decryptError.code fileType:OCTDecryptionErrorFileTypeToxFile];

    return nil;
}

+ (NSData *)getSavedDataFromPath:(NSString *)path
{
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ?
           ([NSData dataWithContentsOfFile:path]) :
           nil;
}

+ (OCTTox *)createToxWithOptions:(OCTToxOptions *)options toxData:(NSData *)toxData error:(NSError **)error
{
    NSError *toxError = nil;

    OCTTox *tox = [[OCTTox alloc] initWithOptions:options savedData:toxData error:&toxError];

    if (tox) {
        return tox;
    }

    OCTToxErrorInitCode code = toxError.code;

    switch (code) {
        case OCTToxErrorInitCodeUnknown:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxUnknown];
            break;
        case OCTToxErrorInitCodeMemoryError:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxMemoryError];
            break;
        case OCTToxErrorInitCodePortAlloc:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxPortAlloc];
            break;
        case OCTToxErrorInitCodeProxyBadType:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxProxyBadType];
            break;
        case OCTToxErrorInitCodeProxyBadHost:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxProxyBadHost];
            break;
        case OCTToxErrorInitCodeProxyBadPort:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxProxyBadPort];
            break;
        case OCTToxErrorInitCodeProxyNotFound:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxProxyNotFound];
            break;
        case OCTToxErrorInitCodeEncrypted:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxEncrypted];
            break;
        case OCTToxErrorInitCodeLoadBadFormat:
            [self fillError:error withInitErrorCode:OCTManagerInitErrorCreateToxBadFormat];
            break;
    }

    return nil;
}

@end
