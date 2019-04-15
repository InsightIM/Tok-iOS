// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <objc/runtime.h>

#import "OCTManagerImpl.h"
#import "OCTTox.h"
#import "OCTToxEncryptSave.h"
#import "OCTManagerConfiguration.h"
#import "OCTManagerFactory.h"
#import "OCTSubmanagerBootstrapImpl.h"
#import "OCTSubmanagerCallsImpl.h"
#import "OCTSubmanagerChatsImpl.h"
#import "OCTSubmanagerFilesImpl.h"
#import "OCTSubmanagerFriendsImpl.h"
#import "OCTSubmanagerObjectsImpl.h"
#import "OCTSubmanagerUserImpl.h"
#import "OCTRealmManager.h"

@interface OCTManagerImpl () <OCTToxDelegate, OCTSubmanagerDataSource>

@property (copy, nonatomic, readonly) OCTManagerConfiguration *currentConfiguration;

@property (strong, nonatomic, readonly) OCTTox *tox;
@property (strong, nonatomic, readonly) NSObject *toxSaveFileLock;

@property (strong, nonatomic, nonnull) OCTToxEncryptSave *encryptSave;

@property (strong, nonatomic, readonly) OCTRealmManager *realmManager;
@property (strong, atomic) NSNotificationCenter *notificationCenter;

@property (strong, nonatomic, readwrite) OCTSubmanagerBootstrapImpl *bootstrap;
@property (strong, nonatomic, readwrite) OCTSubmanagerCallsImpl *calls;
@property (strong, nonatomic, readwrite) OCTSubmanagerChatsImpl *chats;
@property (strong, nonatomic, readwrite) OCTSubmanagerFilesImpl *files;
@property (strong, nonatomic, readwrite) OCTSubmanagerFriendsImpl *friends;
@property (strong, nonatomic, readwrite) OCTSubmanagerObjectsImpl *objects;
@property (strong, nonatomic, readwrite) OCTSubmanagerUserImpl *user;

@end

@implementation OCTManagerImpl

#pragma mark -  Lifecycle

- (instancetype)initWithConfiguration:(OCTManagerConfiguration *)configuration
                                  tox:(OCTTox *)tox
                       toxEncryptSave:(OCTToxEncryptSave *)toxEncryptSave
                         realmManager:(OCTRealmManager *)realmManager
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _currentConfiguration = [configuration copy];

    _tox = tox;
    _tox.delegate = self;
    _toxSaveFileLock = [NSObject new];

    _encryptSave = toxEncryptSave;

    _realmManager = realmManager;
    _notificationCenter = [[NSNotificationCenter alloc] init];

    [_tox start];
    [self saveTox];

    [self createSubmanagers];

    return self;
}

- (void)dealloc
{
    [self killSubmanagers];
    [self.tox stop];
}

#pragma mark -  Public

- (OCTManagerConfiguration *)configuration
{
    return [self.currentConfiguration copy];
}

- (NSString *)exportToxSaveFileAndReturnError:(NSError **)error
{
    @synchronized(self.toxSaveFileLock) {
        NSString *savedDataPath = self.currentConfiguration.fileStorage.pathForToxSaveFile;
        NSString *tempPath = self.currentConfiguration.fileStorage.pathForTemporaryFilesDirectory;
        tempPath = [tempPath stringByAppendingPathComponent:[savedDataPath lastPathComponent]];

        NSFileManager *fileManager = [NSFileManager defaultManager];

        if ([fileManager fileExistsAtPath:tempPath]) {
            [fileManager removeItemAtPath:tempPath error:error];
        }

        if (! [fileManager copyItemAtPath:savedDataPath toPath:tempPath error:error]) {
            return nil;
        }

        return tempPath;
    }
}

- (BOOL)changeEncryptPassword:(nonnull NSString *)newPassword oldPassword:(nonnull NSString *)oldPassword
{
    OCTToxEncryptSave *encryptSave = [self changeToxPassword:newPassword oldPassword:oldPassword];
    if (encryptSave == nil) {
        return NO;
    }

    if (! [self changeDatabasePassword:newPassword oldPassword:oldPassword]) {
        return NO;
    }

    self.encryptSave = encryptSave;
    [self saveTox];

    return YES;
}

- (BOOL)isManagerEncryptedWithPassword:(nonnull NSString *)password
{
    NSString *toxFilePath = self.currentConfiguration.fileStorage.pathForToxSaveFile;

    return [self isDataAtPath:toxFilePath encryptedWithPassword:password];
}

#pragma mark -  OCTSubmanagerDataSource

- (OCTTox *)managerGetTox
{
    return self.tox;
}

- (BOOL)managerIsToxConnected
{
    return (self.user.connectionStatus != OCTToxConnectionStatusNone);
}

- (void)managerSaveTox
{
    return [self saveTox];
}

- (OCTRealmManager *)managerGetRealmManager
{
    return self.realmManager;
}

- (id<OCTFileStorageProtocol>)managerGetFileStorage
{
    return self.currentConfiguration.fileStorage;
}

- (NSNotificationCenter *)managerGetNotificationCenter
{
    return self.notificationCenter;
}

- (BOOL)managerUseFauxOfflineMessaging
{
    return self.currentConfiguration.useFauxOfflineMessaging;
}

#pragma mark -  Private

- (NSData *)getSavedDataFromPath:(NSString *)path
{
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ?
           ([NSData dataWithContentsOfFile:path]) :
           nil;
}

- (BOOL)isDataAtPath:(NSString *)path encryptedWithPassword:(NSString *)password
{
    NSData *savedData = [self getSavedDataFromPath:path];

    if (! savedData) {
        return NO;
    }

    if ([OCTToxEncryptSave isDataEncrypted:savedData]) {
        return [OCTToxEncryptSave decryptData:savedData withPassphrase:password error:nil] != nil;
    }

    return NO;
}

- (void)createSubmanagers
{
    _bootstrap = [self createSubmanagerWithClass:[OCTSubmanagerBootstrapImpl class]];
    _chats = [self createSubmanagerWithClass:[OCTSubmanagerChatsImpl class]];
    _files = [self createSubmanagerWithClass:[OCTSubmanagerFilesImpl class]];
    _friends = [self createSubmanagerWithClass:[OCTSubmanagerFriendsImpl class]];
    _objects = [self createSubmanagerWithClass:[OCTSubmanagerObjectsImpl class]];
    _user = [self createSubmanagerWithClass:[OCTSubmanagerUserImpl class]];

    OCTSubmanagerCallsImpl *calls = [[OCTSubmanagerCallsImpl alloc] initWithTox:_tox];
    calls.dataSource = self;
    _calls = calls;
    [_calls setupAndReturnError:nil];
}

- (void)killSubmanagers
{
    self.bootstrap = nil;
    self.calls = nil;
    self.chats = nil;
    self.files = nil;
    self.friends = nil;
    self.objects = nil;
    self.user = nil;
}

- (id)createSubmanagerWithClass:(Class)class
{
    id<OCTSubmanagerProtocol> submanager = [[class alloc] init];
    submanager.dataSource = self;

    if ([submanager respondsToSelector:@selector(configure)]) {
        [submanager configure];
    }

    return submanager;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    id submanager = [self forwardingTargetForSelector:aSelector];

    if (submanager) {
        return YES;
    }

    return [super respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    struct objc_method_description description = protocol_getMethodDescription(@protocol(OCTToxDelegate), aSelector, NO, YES);

    if (description.name == NULL) {
        // We forward methods only from OCTToxDelegate protocol.
        return nil;
    }

    NSArray *submanagers = @[
        self.bootstrap,
        self.chats,
        self.files,
        self.friends,
        self.objects,
        self.user,
    ];

    for (id delegate in submanagers) {
        if ([delegate respondsToSelector:aSelector]) {
            return delegate;
        }
    }

    return nil;
}

- (void)saveTox
{
    @synchronized(self.toxSaveFileLock) {
        void (^throwException)(NSError *) = ^(NSError *error) {
            NSDictionary *userInfo = nil;

            if (error) {
                userInfo = @{ @"NSError" : error };
            }

            @throw [NSException exceptionWithName:@"saveToxException" reason:error.debugDescription userInfo:userInfo];
        };

        NSData *data = [self.tox save];

        NSError *error;

        data = [self.encryptSave encryptData:data error:&error];

        if (! data) {
            throwException(error);
        }

        if (! [data writeToFile:self.currentConfiguration.fileStorage.pathForToxSaveFile options:NSDataWritingAtomic error:&error]) {
            throwException(error);
        }
    }
}

// On success returns encryptSave with new password.
- (OCTToxEncryptSave *)changeToxPassword:(NSString *)newPassword oldPassword:(NSString *)oldPassword
{
    NSString *toxFilePath = self.currentConfiguration.fileStorage.pathForToxSaveFile;

    if (! [self isDataAtPath:toxFilePath encryptedWithPassword:oldPassword]) {
        return nil;
    }

    __block OCTToxEncryptSave *newEncryptSave;

    @synchronized(self.toxSaveFileLock) {
        // Passing nil as tox data as we are setting new password.
        newEncryptSave = [[OCTToxEncryptSave alloc] initWithPassphrase:newPassword toxData:nil error:nil];
    }

    return newEncryptSave;
}

- (BOOL)changeDatabasePassword:(NSString *)newPassword oldPassword:(NSString *)oldPassword
{
    NSParameterAssert(newPassword);
    NSParameterAssert(oldPassword);

    NSString *encryptedKeyPath = self.currentConfiguration.fileStorage.pathForDatabaseEncryptionKey;
    NSData *encryptedKey = [NSData dataWithContentsOfFile:encryptedKeyPath];

    if (! encryptedKey) {
        return NO;
    }

    NSData *key = [OCTToxEncryptSave decryptData:encryptedKey withPassphrase:oldPassword error:nil];

    if (! key) {
        return NO;
    }

    NSData *newEncryptedKey = [OCTToxEncryptSave encryptData:key withPassphrase:newPassword error:nil];

    if (! newEncryptedKey) {
        return NO;
    }

    return [newEncryptedKey writeToFile:encryptedKeyPath options:NSDataWritingAtomic error:nil];
}

@end
