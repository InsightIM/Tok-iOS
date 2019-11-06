// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerFriendsImpl.h"
#import "OCTTox.h"
#import "OCTFriend.h"
#import "OCTFriendRequest.h"
#import "OCTRealmManager.h"

@interface OCTSubmanagerFriendsImpl ()

@end

@implementation OCTSubmanagerFriendsImpl
@synthesize dataSource = _dataSource;

#pragma mark -  Public

- (OCTFriend *)friendWithPublicKeyIgnoreState:(NSString *)publicKey
{
    if (publicKey == nil) {
        return nil;
    }
    
    return [[self.dataSource managerGetRealmManager] friendWithPublicKey:publicKey];
}

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey friendState:(NSInteger)friendState
{
    if (publicKey == nil) {
        return nil;
    }
    
    return [[self.dataSource managerGetRealmManager] friendWithPublicKey:publicKey friendState:friendState];
}

- (BOOL)sendFriendRequestToAddress:(NSString *)address message:(NSString *)message alias:(NSString *)alias error:(NSError **)error
{
    NSParameterAssert(address);
    NSParameterAssert(message);

    OCTTox *tox = [self.dataSource managerGetTox];

    OCTToxFriendNumber friendNumber = [tox addFriendWithAddress:address message:message error:error];

    if (friendNumber == kOCTToxFriendNumberFailure) {
        return NO;
    }

    [self.dataSource managerSaveTox];
    
    NSString *publicKey = [address substringToIndex:kOCTToxPublicKeyLength];
    [self.dataSource.managerGetRealmManager addFriendRequestWithMessage:message publicKey:publicKey isOutgoing:YES];
    
    BOOL result = [self createFriendWithFriendNumber:friendNumber alias:alias friendState:1 error:error];
    if (result) {
        // Send friend request to offlinebot
        OCTFriend *friend = [[self.dataSource managerGetRealmManager] friendWithPublicKey:publicKey];
        [self.dataSource.managerGetNotificationCenter postNotificationName:kOCTSendOfflineFriendRequestNotification
                                                                    object:friend
                                                                  userInfo:@{@"message": message}];
    }
    return result;
}

- (BOOL)sendBotFriendRequestToAddress:(NSString *)address message:(NSString *)message error:(NSError **)error
{
    NSParameterAssert(address);
    NSParameterAssert(message);
    
    OCTTox *tox = [self.dataSource managerGetTox];
    
    OCTToxFriendNumber friendNumber = [tox addFriendWithAddress:address message:message error:error];
    
    if (friendNumber == kOCTToxFriendNumberFailure) {
        return NO;
    }
    
    [self.dataSource managerSaveTox];
    
    return [self createFriendWithFriendNumber:friendNumber alias:nil friendState:0 error:error];
}

- (BOOL)friendAcceptRequest:(NSString *)publicKey
{
    NSParameterAssert(publicKey);
    
    return [self.dataSource.managerGetRealmManager friendAcceptRequest:publicKey];
}

- (BOOL)approveFriendRequest:(OCTFriendRequest *)friendRequest alias:(NSString *)alias error:(NSError **)error
{
    NSParameterAssert(friendRequest);

    OCTTox *tox = [self.dataSource managerGetTox];

    OCTToxFriendNumber friendNumber = [tox addFriendWithNoRequestWithPublicKey:friendRequest.publicKey error:error];

    if (friendNumber == kOCTToxFriendNumberFailure) {
        return NO;
    }

    [self.dataSource managerSaveTox];

    [[self.dataSource managerGetRealmManager] deleteObject:friendRequest];

    return [self createFriendWithFriendNumber:friendNumber alias:alias friendState:0 error:error];
}

- (void)refuseFriendRequest:(OCTFriendRequest *)friendRequest
{
    NSParameterAssert(friendRequest);
    [[self.dataSource managerGetRealmManager] updateObject:friendRequest withBlock:^(OCTFriendRequest *theFriendRequest) {
        theFriendRequest.status = 1;
    }];
}

- (void)removeFriendRequest:(OCTFriendRequest *)friendRequest
{
    NSParameterAssert(friendRequest);

    [[self.dataSource managerGetRealmManager] deleteObject:friendRequest];
}

- (BOOL)removeFriend:(OCTFriend *)friend error:(NSError **)error
{
    NSParameterAssert(friend);

    OCTTox *tox = [self.dataSource managerGetTox];

    if (! [tox deleteFriendWithFriendNumber:friend.friendNumber error:error]) {
        return NO;
    }

    [self.dataSource managerSaveTox];

    [[self.dataSource managerGetRealmManager] deleteObject:friend];

    return YES;
}

#pragma mark -  Private category

- (void)configure
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
            OCTTox *tox = [self.dataSource managerGetTox];
            RLMRealm *db = realmManager.database;
            [realmManager updateObjectsWithClass:[OCTFriend class] predicate:nil db:db updateBlock:^(OCTFriend *friend) {
                // Tox may change friendNumber after relaunch, resetting them.
                friend.friendNumber = kOCTToxFriendNumberFailure;
            }];
            
            for (NSNumber *friendNumber in [tox friendsArray]) {
                OCTToxFriendNumber number = [friendNumber intValue];
                NSError *error;
                
                NSString *publicKey = [tox publicKeyFromFriendNumber:number error:&error];
                
                if (! publicKey) {
                    @throw [NSException exceptionWithName:@"Cannot find publicKey for existing friendNumber, Tox save data is broken"
                                                   reason:error.debugDescription
                                                 userInfo:nil];
                }
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"publicKey == %@", publicKey];
                RLMResults *results = [realmManager objectsWithClass:[OCTFriend class] predicate:predicate db:db];
                
                if (results.count == 0) {
                    // It seems that friend is in Tox but isn't in Realm. Let's add it.
                    [self createFriendWithFriendNumber:number alias:nil friendState:0 error:nil];
                    continue;
                }
                
                OCTFriend *friend = [results firstObject];
                
                // Reset some fields for friends.
                [realmManager updateObject:friend db:db withBlock:^(OCTFriend *theFriend) {
                    theFriend.friendNumber = number;
                    theFriend.status = OCTToxUserStatusNone;
                    theFriend.isConnected = NO;
                    theFriend.connectionStatus = OCTToxConnectionStatusNone;
                    theFriend.isTyping = NO;
                    NSDate *dateOffline = [tox friendGetLastOnlineWithFriendNumber:number error:nil];
                    theFriend.lastSeenOnlineInterval = [dateOffline timeIntervalSince1970];
                    theFriend.clientVersion = 0;
                    theFriend.supportOfflineMessage = YES;
                }];
            }
            
            // Remove all OCTFriend's which aren't bounded to tox. User cannot interact with them anyway.
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"friendNumber == %d", kOCTToxFriendNumberFailure];
            RLMResults *results = [realmManager objectsWithClass:[OCTFriend class] predicate:predicate db:db];
            
            for (OCTFriend *friend in results) {
                [realmManager deleteObject:friend db:db];
            }
        }
    });
}

#pragma mark -  OCTToxDelegate

- (void)tox:(OCTTox *)tox friendRequestWithMessage:(NSString *)message publicKey:(NSString *)publicKey
{
    [self.dataSource.managerGetRealmManager addFriendRequestWithMessage:message publicKey:publicKey isOutgoing:NO];
}

- (void)tox:(OCTTox *)tox friendNameUpdate:(NSString *)name friendNumber:(OCTToxFriendNumber)friendNumber
{
    [self.dataSource managerSaveTox];

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];

    RLMRealm *db = realmManager.database;
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *theFriend = [realmManager friendWithPublicKey:publicKey db:db];

    [db beginWriteTransaction];
    if (name.length > 0
        && ([theFriend.nickname isEqualToString:[theFriend.publicKey substringToIndex:8]]
            || [theFriend.nickname isEqualToString:theFriend.publicKey]
            || [theFriend.nickname isEqualToString:theFriend.name])) {
            theFriend.nickname = name;
        }
    theFriend.name = name;
    [db commitWriteTransaction];
}

- (void)tox:(OCTTox *)tox friendStatusMessageUpdate:(NSString *)statusMessage friendNumber:(OCTToxFriendNumber)friendNumber
{
    [self.dataSource managerSaveTox];

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    RLMRealm *db = realmManager.database;
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey db:db];

    [db beginWriteTransaction];
    friend.statusMessage = statusMessage;
    [db commitWriteTransaction];
}

- (void)tox:(OCTTox *)tox friendStatusUpdate:(OCTToxUserStatus)status friendNumber:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];

    [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
        theFriend.status = status;
    }];
}

- (void)tox:(OCTTox *)tox friendIsTypingUpdate:(BOOL)isTyping friendNumber:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];

    [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
        theFriend.isTyping = isTyping;
    }];
}

- (void)tox:(OCTTox *)tox friendConnectionStatusChanged:(OCTToxConnectionStatus)status friendNumber:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    RLMRealm *db = realmManager.database;
    OCTFriend *theFriend = [realmManager friendWithPublicKey:publicKey db:db];
    
    if (status != OCTToxConnectionStatusNone) {
        [realmManager friendAcceptRequest:theFriend.publicKey db:db];
    }
    
    [db beginWriteTransaction];
    theFriend.isConnected = (status != OCTToxConnectionStatusNone);
    theFriend.connectionStatus = status;
    
    if (! theFriend.isConnected) {
        NSDate *dateOffline = [tox friendGetLastOnlineWithFriendNumber:friendNumber error:nil];
        NSTimeInterval timeSince = [dateOffline timeIntervalSince1970];
        theFriend.lastSeenOnlineInterval = timeSince;
        theFriend.clientVersion = 0;
    }
    [db commitWriteTransaction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{@"friendNumber": @(friendNumber), @"status": @(status)};
        [[NSNotificationCenter defaultCenter] postNotificationName:kOCTFriendConnectionStatusChangeNotification object:nil userInfo:userInfo];
        [[self.dataSource managerGetNotificationCenter] postNotificationName:kOCTFriendConnectionStatusChangeNotification object:publicKey];
    });
}

#pragma mark -  Private

- (BOOL)createFriendWithFriendNumber:(OCTToxFriendNumber)friendNumber alias:(NSString *)alias friendState:(NSInteger)friendState error:(NSError **)userError
{
    OCTTox *tox = [self.dataSource managerGetTox];
    NSError *error;

    OCTFriend *friend = [OCTFriend new];

    friend.friendNumber = friendNumber;

    friend.publicKey = [tox publicKeyFromFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

    friend.name = [tox friendNameWithFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

    friend.statusMessage = [tox friendStatusMessageWithFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

//    friend.status = [tox friendStatusWithFriendNumber:friendNumber error:&error];
//    if ([self checkForError:error andAssignTo:userError]) {
//        return NO;
//    }

    friend.connectionStatus = [tox friendConnectionStatusWithFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

//    NSDate *lastSeenOnline = [tox friendGetLastOnlineWithFriendNumber:friendNumber error:&error];
//    friend.lastSeenOnlineInterval = [lastSeenOnline timeIntervalSince1970];
//    if ([self checkForError:error andAssignTo:userError]) {
//        return NO;
//    }
//
//    friend.isTyping = [tox isFriendTypingWithFriendNumber:friendNumber error:&error];
//    if ([self checkForError:error andAssignTo:userError]) {
//        return NO;
//    }

    friend.isConnected = (friend.connectionStatus != OCTToxConnectionStatusNone);
    friend.friendState = friendState;
    if (alias && alias.length > 0) {
        friend.nickname = alias;
    } else {
        friend.nickname = friend.name.length ? friend.name : [friend.publicKey substringToIndex:8];
    }
    
    RLMRealm *db = [self.dataSource managerGetRealmManager].database;
    [db beginWriteTransaction];
    [db addObject:friend];
    [db commitWriteTransaction];
    
    return YES;
}

- (BOOL)checkForError:(NSError *)toCheck andAssignTo:(NSError **)toAssign
{
    if (! toCheck) {
        return NO;
    }

    if (toAssign) {
        *toAssign = toCheck;
    }

    return YES;
}

@end
