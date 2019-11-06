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

static NSString *const kOCTMessageDelivedNotification = @"kOCTMessageDelivedNotification";

static NSString *const kOCTFileMessageReceivedControlNotification = @"kOCTFileMessageReceivedControlNotification";

static NSString *const kOCTFileMessageChunkRequestNotification = @"kOCTFileMessageChunkRequestNotification";

static NSString *const kOCTFileMessageReceivedNotification = @"kOCTFileMessageReceivedNotification";

static NSString *const kOCTFileMessageReceivedChunkNotification = @"kOCTFileMessageReceivedChunkNotification";

static NSString *const kOCTBotFileMessageReceivedNotification = @"kOCTBotFileMessageReceivedNotification";

static NSString *const kOCTStrangerMessageReceivedNotification = @"kOCTStrangerMessageReceivedNotification";

static NSString *const kOCTStrangerAvatarReceivedNotification = @"kOCTStrangerAvatarReceivedNotification";

static NSString *const kOCTStrangerSignatureReceivedNotification = @"kOCTStrangerSignatureReceivedNotification";

static NSString *const kOCTGroupPeerListReceivedNotification = @"kOCTGroupPeerListReceivedNotification";

static NSString *const kOCTGroupInfoReceivedNotification = @"kOCTGroupInfoReceivedNotification";

static NSString *const kOCTGroupInviteReceivedNotification = @"kOCTGroupInviteReceivedNotification";

static NSString *const kOCTSendOfflineFriendRequestNotification = @"kOCTSendOfflineFriendRequestNotification";

static NSString *const kOCTGroupRecommendListReceivedNotification = @"kOCTGroupRecommendListReceivedNotification";

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
- (NSString *)getOfflineMessageBotPublicKey;
- (NSString *)getGroupMessageBotPublicKey;
- (NSString *)getStrangerMessageBotPublicKey;
- (BOOL)managerIsToxConnected;
- (void)managerSaveTox;
- (OCTRealmManager *)managerGetRealmManager;
- (id<OCTFileStorageProtocol>)managerGetFileStorage;
- (NSNotificationCenter *)managerGetNotificationCenter;
- (BOOL)managerUseFauxOfflineMessaging;

@end
