// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerFriendsImpl.h"
#import "OCTTox.h"
#import "OCTFriend.h"
#import "OCTFriendRequest.h"
#import "OCTRealmManager.h"
#import "MessageOperationManager.h"

@interface OCTSubmanagerFriendsImpl ()

@property (nonatomic, strong, readonly) MessageOperationManager *messageOperationManager;

@end

@implementation OCTSubmanagerFriendsImpl
@synthesize dataSource = _dataSource;

#pragma mark -  Public

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey
{
    if (publicKey == nil) {
        return nil;
    }
    
    return [[self.dataSource managerGetRealmManager] friendWithPublicKey:publicKey];
}

- (BOOL)sendFriendRequestToAddress:(NSString *)address message:(NSString *)message error:(NSError **)error
{
    NSParameterAssert(address);
    NSParameterAssert(message);

    OCTTox *tox = [self.dataSource managerGetTox];

    OCTToxFriendNumber friendNumber = [tox addFriendWithAddress:address message:message error:error];

    if (friendNumber == kOCTToxFriendNumberFailure) {
        return NO;
    }

    [self.dataSource managerSaveTox];

    return [self createFriendWithFriendNumber:friendNumber error:error];
}

- (BOOL)approveFriendRequest:(OCTFriendRequest *)friendRequest error:(NSError **)error
{
    NSParameterAssert(friendRequest);

    OCTTox *tox = [self.dataSource managerGetTox];

    OCTToxFriendNumber friendNumber = [tox addFriendWithNoRequestWithPublicKey:friendRequest.publicKey error:error];

    if (friendNumber == kOCTToxFriendNumberFailure) {
        return NO;
    }

    [self.dataSource managerSaveTox];

    [[self.dataSource managerGetRealmManager] deleteObject:friendRequest];

    return [self createFriendWithFriendNumber:friendNumber error:error];
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
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    OCTTox *tox = [self.dataSource managerGetTox];
    
    _messageOperationManager = [[MessageOperationManager alloc] initWithTox:tox realmManager:realmManager];

    [realmManager updateObjectsWithClass:[OCTFriend class] predicate:nil updateBlock:^(OCTFriend *friend) {
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
        RLMResults *results = [realmManager objectsWithClass:[OCTFriend class] predicate:predicate];

        if (results.count == 0) {
            // It seems that friend is in Tox but isn't in Realm. Let's add it.
            [self createFriendWithFriendNumber:number error:nil];
            continue;
        }

        OCTFriend *friend = [results firstObject];

        // Reset some fields for friends.
        [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
            theFriend.friendNumber = number;
            theFriend.status = OCTToxUserStatusNone;
            theFriend.isConnected = NO;
            theFriend.connectionStatus = OCTToxConnectionStatusNone;
            theFriend.isTyping = NO;
            NSDate *dateOffline = [tox friendGetLastOnlineWithFriendNumber:number error:nil];
            theFriend.lastSeenOnlineInterval = [dateOffline timeIntervalSince1970];
            theFriend.clientVersion = 0;
            theFriend.supportOfflineMessage = NO;
        }];
    }

    // Remove all OCTFriend's which aren't bounded to tox. User cannot interact with them anyway.
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"friendNumber == %d", kOCTToxFriendNumberFailure];
    RLMResults *results = [realmManager objectsWithClass:[OCTFriend class] predicate:predicate];

    for (OCTFriend *friend in results) {
        [realmManager deleteObject:friend];
    }
}

#pragma mark -  OCTToxDelegate

- (void)tox:(OCTTox *)tox friendRequestWithMessage:(NSString *)message publicKey:(NSString *)publicKey
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"publicKey == %@", publicKey];
    RLMResults *results = [realmManager objectsWithClass:[OCTFriendRequest class] predicate:predicate];
    if (results.count > 0) {
        // friendRequest already exists
        return;
    }

    results = [realmManager objectsWithClass:[OCTFriend class] predicate:predicate];
    if (results.count > 0) {
        // friend with such publicKey already exists
        return;
    }

    OCTFriendRequest *request = [OCTFriendRequest new];
    request.publicKey = publicKey;
    request.message = message;
    request.dateInterval = [[NSDate date] timeIntervalSince1970];

    [realmManager addObject:request];
}

- (void)tox:(OCTTox *)tox friendNameUpdate:(NSString *)name friendNumber:(OCTToxFriendNumber)friendNumber
{
    [self.dataSource managerSaveTox];

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];

    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];

    [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
        if (name.length > 0 && ([theFriend.nickname isEqualToString:theFriend.publicKey] || [theFriend.nickname isEqualToString:theFriend.name])) {                theFriend.nickname = name;
        }
        theFriend.name = name;
    }];
}

- (void)tox:(OCTTox *)tox friendStatusMessageUpdate:(NSString *)statusMessage friendNumber:(OCTToxFriendNumber)friendNumber
{
    [self.dataSource managerSaveTox];

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];

    [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
        theFriend.statusMessage = statusMessage;
    }];
}

- (void)tox:(OCTTox *)tox friendStatusUpdate:(OCTToxUserStatus)status friendNumber:(OCTToxFriendNumber)friendNumber
{
    [self.dataSource managerSaveTox];

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
    [self.dataSource managerSaveTox];

    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    
    if (status != OCTToxConnectionStatusNone && friend.clientVersion == 0) {
        [_messageOperationManager sendAssistMessageWithFriendNumber:friendNumber];
    }

    [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
        theFriend.isConnected = (status != OCTToxConnectionStatusNone);
        theFriend.connectionStatus = status;

        if (! theFriend.isConnected) {
            NSDate *dateOffline = [tox friendGetLastOnlineWithFriendNumber:friendNumber error:nil];
            NSTimeInterval timeSince = [dateOffline timeIntervalSince1970];
            theFriend.lastSeenOnlineInterval = timeSince;
            theFriend.clientVersion = 0;
        }
    }];

    [[self.dataSource managerGetNotificationCenter] postNotificationName:kOCTFriendConnectionStatusChangeNotification object:friend];
}

- (void)tox:(OCTTox *)tox version:(uint32_t)version friendNumber:(OCTToxFriendNumber)friendNumber
{
    OCTRealmManager *realmManager = [self.dataSource managerGetRealmManager];
    NSString *publicKey = [[self.dataSource managerGetTox] publicKeyFromFriendNumber:friendNumber error:nil];
    OCTFriend *friend = [realmManager friendWithPublicKey:publicKey];
    
    if (friend.clientVersion == version) {
        return;
    }
    
    [realmManager updateObject:friend withBlock:^(OCTFriend *theFriend) {
        theFriend.clientVersion = version;
    }];
}

#pragma mark -  Private

- (BOOL)createFriendWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)userError
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

    friend.status = [tox friendStatusWithFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

    friend.connectionStatus = [tox friendConnectionStatusWithFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

    NSDate *lastSeenOnline = [tox friendGetLastOnlineWithFriendNumber:friendNumber error:&error];
    friend.lastSeenOnlineInterval = [lastSeenOnline timeIntervalSince1970];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

    friend.isTyping = [tox isFriendTypingWithFriendNumber:friendNumber error:&error];
    if ([self checkForError:error andAssignTo:userError]) {
        return NO;
    }

    friend.isConnected = (friend.connectionStatus != OCTToxConnectionStatusNone);
    friend.nickname = friend.name.length ? friend.name : friend.publicKey;

    [[self.dataSource managerGetRealmManager] addObject:friend];

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
