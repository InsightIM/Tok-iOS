// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTObject.h"

@interface OCTSettingsStorageObject : OCTObject

@property BOOL bootstrapDidConnect;

/**
 * UIImage with avatar of user.
 */
@property NSData *userAvatarData;

/**
 * Generic data to be used by user of the library.
 * It shouldn't be used by objcTox itself.
 */
@property NSData *genericSettingsData;

@end
