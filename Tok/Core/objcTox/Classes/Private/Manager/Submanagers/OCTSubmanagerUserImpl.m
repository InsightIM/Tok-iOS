// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerUserImpl.h"
#import "OCTTox.h"
#import "OCTManagerConstants.h"
#import "OCTRealmManager.h"
#import "OCTSettingsStorageObject.h"

@implementation OCTSubmanagerUserImpl
@synthesize delegate = _delegate;
@synthesize dataSource = _dataSource;

#pragma mark -  Properties

- (OCTToxConnectionStatus)connectionStatus
{
    return [self.dataSource managerGetTox].connectionStatus;
}

- (NSString *)userAddress
{
    return [self.dataSource managerGetTox].userAddress;
}

- (NSString *)publicKey
{
    return [self.dataSource managerGetTox].publicKey;
}

#pragma mark -  Public

- (OCTToxNoSpam)nospam
{
    return [self.dataSource managerGetTox].nospam;
}

- (void)setNospam:(OCTToxNoSpam)nospam
{
    [self.dataSource managerGetTox].nospam = nospam;
    [self.dataSource managerSaveTox];
}

- (OCTToxUserStatus)userStatus
{
    return [self.dataSource managerGetTox].userStatus;
}

- (void)setUserStatus:(OCTToxUserStatus)userStatus
{
    [self.dataSource managerGetTox].userStatus = userStatus;
}

- (BOOL)setUserName:(NSString *)name error:(NSError **)error
{
    if ([[self.dataSource managerGetTox] setNickname:name error:error]) {
        [self.dataSource managerSaveTox];
        return YES;
    }

    return NO;
}

- (NSString *)userName
{
    return [[self.dataSource managerGetTox] userName];
}

- (BOOL)setUserStatusMessage:(NSString *)statusMessage error:(NSError **)error
{
    if ([[self.dataSource managerGetTox] setUserStatusMessage:statusMessage error:error]) {
        [self.dataSource managerSaveTox];
        return YES;
    }

    return NO;
}

- (NSString *)userStatusMessage
{
    return [[self.dataSource managerGetTox] userStatusMessage];
}

- (BOOL)setUserAvatar:(NSData *)avatar error:(NSError **)error
{
    if (avatar && (avatar.length > kOCTManagerMaxAvatarSize)) {
        if (error) {
            *error = [NSError errorWithDomain:kOCTManagerErrorDomain
                                         code:OCTSetUserAvatarErrorTooBig
                                     userInfo:@{
                          NSLocalizedDescriptionKey : @"Cannot set user avatar",
                          NSLocalizedFailureReasonErrorKey : @"Avatar is too big",
                      }];
        }
        return NO;
    }

    OCTRealmManager *realmManager = self.dataSource.managerGetRealmManager;

    [realmManager updateObject:realmManager.settingsStorage withBlock:^(OCTSettingsStorageObject *object) {
        object.userAvatarData = avatar.length > 0 ? avatar : nil;
    }];

    [[NSNotificationCenter defaultCenter] postNotificationName:kOCTUserAvatarWasUpdatedNotification object:nil];
    [self.dataSource.managerGetNotificationCenter postNotificationName:kOCTUserAvatarWasUpdatedNotification object:nil];

    return YES;
}

- (NSData *)userAvatar
{
    return self.dataSource.managerGetRealmManager.settingsStorage.userAvatarData;
}

#pragma mark -  OCTToxDelegate

- (void)tox:(OCTTox *)tox connectionStatus:(OCTToxConnectionStatus)connectionStatus
{
    [self.delegate submanagerUser:self connectionStatusUpdate:connectionStatus];
}

@end
