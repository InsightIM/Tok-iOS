// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class OCTManagerConfiguration, OCTTox;
@protocol OCTManager, OCTToxDelegate;

@interface OCTManagerFactory : NSObject

/**
 * Create manager with configuration. There is no way to change configuration after init method. If you'd like to
 * change it you have to recreate OCTManager.
 *
 * @param configuration Configuration to be used.
 * @param encryptPassword Password used to encrypt/decrypt tox save file and database.
 *        Tox file will be encrypted automatically if it wasn't encrypted before.
 * @param successBlock Block called on success with initialized OCTManager. Will be called on main thread.
 * @param failureBlock Block called on failure. Will be called on main thread.
 *     error If an error occurs, this pointer is set to an actual error object containing the error information.
 *     See OCTManagerInitError for all error codes.
 *
 * @warning This method should be called on main thread.
 */
+ (void)managerWithConfiguration:(OCTManagerConfiguration *)configuration
                 encryptPassword:(NSString *)encryptPassword
                    dhtArrayBlock:(NSArray <NSDictionary <NSString *, id>*>*(^)(OCTTox *tox))dhtArrayBlock
                        delegate:(id<OCTToxDelegate>)delegate
                    successBlock:(nullable void (^)(id<OCTManager> manager))successBlock
                    failureBlock:(nullable void (^)(NSError *error))failureBlock;

+ (void)buildWithConfiguration:(OCTManagerConfiguration *)configuration
               encryptPassword:(nonnull NSString *)encryptPassword
                  successBlock:(void (^)(NSDictionary *result))successBlock
                  failureBlock:(void (^)(NSError *error))failureBlock;

@end

NS_ASSUME_NONNULL_END
