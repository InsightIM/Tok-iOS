// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

#import "OCTFileStorageProtocol.h"
#import "OCTToxOptions.h"

/**
 * Configuration for OCTManager.
 */
@interface OCTManagerConfiguration : NSObject <NSCopying>

/**
 * File storage to use.
 *
 * Default values: OCTDefaultFileStorage will be used with following parameters:
 * - tox save file is stored at "{app document directory}/me.dvor.objcTox/save.tox"
 * - database file is stored at "{app document directory}/me.dvor.objcTox/database"
 * - database encryption key file is stored at "{app document directory}/me.dvor.objcTox/database.encryptionkey"
 * - downloaded files are stored at "{app document directory}/me.dvor.objcTox/downloads"
 * - uploaded files are stored at "{app document directory}/me.dvor.objcTox/uploads"
 * - avatars are stored at "{app document directory}/me.dvor.objcTox/avatars"
 * - temporary files are stored at NSTemporaryDirectory()
 */
@property (strong, nonatomic, nonnull) id<OCTFileStorageProtocol> fileStorage;

/**
 * Options for tox to use.
 */
@property (strong, nonatomic, nonnull) OCTToxOptions *options;

/**
 * If this parameter is set, tox save file will be copied from given path.
 * You can set this property to import tox save from some other location.
 *
 * Default value: nil.
 */
@property (strong, nonatomic, nullable) NSString *importToxSaveFromPath;

/**
 * When faux offline messaging is enabled, it is allowed to send message to
 * offline friends. In that case message would be stored in database and resend
 * when friend comes online.
 *
 * Default value: YES.
 */
@property (assign, nonatomic) BOOL useFauxOfflineMessaging;

/**
 * This is default configuration for manager.
 * Each property of OCTManagerConfiguration has "Default value" field. This method returns configuration
 * with those default values set.
 *
 * @return Default configuration for OCTManager.
 */
+ (nonnull instancetype)defaultConfiguration;

@end
