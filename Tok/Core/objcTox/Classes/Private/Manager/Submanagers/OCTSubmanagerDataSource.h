// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

@class OCTTox;
@class OCTRealmManager;
@protocol OCTFileStorageProtocol;

/**
 * Notification is send when connection status of friend has changed.
 *
 * - object OCTFriend whose status has changed.
 * - userInfo nil
 */
static NSString *const kOCTFriendConnectionStatusChangeNotification = @"kOCTFriendConnectionStatusChangeNotification";

/**
 * Notification is send on user avatar update.
 *
 * - object nil
 * - userInfo nil
 */
static NSString *const kOCTUserAvatarWasUpdatedNotification = @"kOCTUserAvatarWasUpdatedNotification";

/**
 * Send this notifications to schedule cleanup of uploaded/downloaded files. All files without OCTMessageFile
 * will be removed.
 *
 * - object nil
 * - userInfo nil
 */
static NSString *const kOCTScheduleFileTransferCleanupNotification = @"kOCTScheduleFileTransferCleanupNotification";

@protocol OCTSubmanagerDataSource <NSObject>

- (OCTTox *)managerGetTox;
- (BOOL)managerIsToxConnected;
- (void)managerSaveTox;
- (OCTRealmManager *)managerGetRealmManager;
- (id<OCTFileStorageProtocol>)managerGetFileStorage;
- (NSNotificationCenter *)managerGetNotificationCenter;
- (BOOL)managerUseFauxOfflineMessaging;

@end
