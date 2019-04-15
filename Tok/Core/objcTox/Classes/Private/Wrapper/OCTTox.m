// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTTox+Private.h"
#import "OCTToxOptions+Private.h"
#import "OCTLogging.h"

void (*_tox_self_get_public_key)(const Tox *tox, uint8_t *public_key);

@interface OCTTox ()

@property (assign, nonatomic) Tox *tox;

@property (strong, nonatomic) dispatch_source_t timer;
@property (assign, nonatomic) uint64_t previousIterate;

@end

@implementation OCTTox

#pragma mark -  Class methods

+ (NSUInteger)clientVersion
{
    return CLIENT_VRTSION;
}

+ (NSString *)version
{
    return [NSString stringWithFormat:@"%lu.%lu.%lu",
            (unsigned long)[self versionMajor], (unsigned long)[self versionMinor], (unsigned long)[self versionPatch]];
}

+ (NSUInteger)versionMajor
{
    return tox_version_major();
}

+ (NSUInteger)versionMinor
{
    return tox_version_minor();
}

+ (NSUInteger)versionPatch
{
    return tox_version_patch();
}

#pragma mark -  Lifecycle

- (instancetype)initWithOptions:(OCTToxOptions *)options savedData:(NSData *)data error:(NSError **)error
{
    NSParameterAssert(options);
    
    self = [super init];
    
    OCTLogVerbose(@"OCTTox: loading with options %@", options);
    
    if (data) {
        OCTLogVerbose(@"loading from data of length %lu", (unsigned long)data.length);
        tox_options_set_savedata_type(options.options, TOX_SAVEDATA_TYPE_TOX_SAVE);
        tox_options_set_savedata_data(options.options, data.bytes, data.length);
    }
    else {
        tox_options_set_savedata_type(options.options, TOX_SAVEDATA_TYPE_NONE);
    }
    
    tox_options_set_log_callback(options.options, logCallback);
    
    TOX_ERR_NEW cError;
    
    _tox = tox_new(options.options, &cError);
    
    [self fillError:error withCErrorInit:cError];
    
    if (! _tox) {
        return nil;
    }
    
    [self setupCFunctions];
    [self setupCallbacks];
    
    return self;
}

- (void)dealloc
{
    [self stop];
    
    if (self.tox) {
        tox_kill(self.tox);
    }
    
    OCTLogVerbose(@"dealloc called, tox killed");
}

- (NSData *)save
{
    OCTLogVerbose(@"saving...");
    
    size_t size = tox_get_savedata_size(self.tox);
    uint8_t *cData = malloc(size);
    
    tox_get_savedata(self.tox, cData);
    
    NSData *data = [NSData dataWithBytes:cData length:size];
    free(cData);
    
    OCTLogInfo(@"saved to data with length %lu", (unsigned long)data.length);
    
    return data;
}

- (void)start
{
    OCTLogVerbose(@"start method called");
    
    @synchronized(self) {
        if (self.timer) {
            OCTLogWarn(@"already started");
            return;
        }
        
        dispatch_queue_t queue = dispatch_queue_create("me.dvor.objcTox.OCTToxQueue", NULL);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        
        [self updateTimerIntervalIfNeeded];
        
        __weak OCTTox *weakSelf = self;
        dispatch_source_set_event_handler(self.timer, ^{
            OCTTox *strongSelf = weakSelf;
            if (! strongSelf) {
                return;
            }
            
            tox_iterate(strongSelf.tox, (__bridge void *)self);
            
            [strongSelf updateTimerIntervalIfNeeded];
        });
        
        dispatch_resume(self.timer);
    }
    
    OCTLogInfo(@"started");
}

- (void)stop
{
    OCTLogVerbose(@"stop method called");
    
    @synchronized(self) {
        if (! self.timer) {
            OCTLogWarn(@"tox isn't running, nothing to stop");
            return;
        }
        
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    
    OCTLogInfo(@"stopped");
}

#pragma mark -  Properties

- (OCTToxConnectionStatus)connectionStatus
{
    return [self userConnectionStatusFromCUserStatus:tox_self_get_connection_status(self.tox)];
}

- (NSString *)userAddress
{
    OCTLogVerbose(@"get userAddress");
    
    const NSUInteger length = TOX_ADDRESS_SIZE;
    uint8_t *cAddress = malloc(length);
    
    tox_self_get_address(self.tox, cAddress);
    
    if (! cAddress) {
        return nil;
    }
    
    NSString *address = [OCTTox binToHexString:cAddress length:length];
    
    free(cAddress);
    
    return address;
}

- (NSString *)publicKey
{
    OCTLogVerbose(@"get publicKey");
    
    uint8_t *cPublicKey = malloc(TOX_PUBLIC_KEY_SIZE);
    
    _tox_self_get_public_key(self.tox, cPublicKey);
    
    NSString *publicKey = [OCTTox binToHexString:cPublicKey length:TOX_PUBLIC_KEY_SIZE];
    free(cPublicKey);
    
    return publicKey;
}

- (NSString *)secretKey
{
    OCTLogVerbose(@"get secretKey");
    
    uint8_t *cSecretKey = malloc(TOX_SECRET_KEY_SIZE);
    
    tox_self_get_secret_key(self.tox, cSecretKey);
    
    NSString *secretKey = [OCTTox binToHexString:cSecretKey length:TOX_SECRET_KEY_SIZE];
    free(cSecretKey);
    
    return secretKey;
}

- (void)setNospam:(OCTToxNoSpam)nospam
{
    OCTLogVerbose(@"set nospam");
    tox_self_set_nospam(self.tox, nospam);
}

- (OCTToxNoSpam)nospam
{
    OCTLogVerbose(@"get nospam");
    return tox_self_get_nospam(self.tox);
}

- (void)setUserStatus:(OCTToxUserStatus)status
{
    TOX_USER_STATUS cStatus = TOX_USER_STATUS_NONE;
    
    switch (status) {
        case OCTToxUserStatusNone:
            cStatus = TOX_USER_STATUS_NONE;
            break;
        case OCTToxUserStatusAway:
            cStatus = TOX_USER_STATUS_AWAY;
            break;
        case OCTToxUserStatusBusy:
            cStatus = TOX_USER_STATUS_BUSY;
            break;
    }
    
    tox_self_set_status(self.tox, cStatus);
    
    OCTLogInfo(@"set user status to %lu", (unsigned long)status);
}

- (OCTToxUserStatus)userStatus
{
    return [self userStatusFromCUserStatus:tox_self_get_status(self.tox)];
}

#pragma mark -  Methods

- (BOOL)bootstrapFromHost:(NSString *)host port:(OCTToxPort)port publicKey:(NSString *)publicKey error:(NSError **)error
{
    NSParameterAssert(host);
    NSParameterAssert(publicKey);
    
    OCTLogInfo(@"bootstrap with host %@ port %d publicKey %@", host, port, publicKey);
    
    const char *cAddress = host.UTF8String;
    uint8_t *cPublicKey = [OCTTox hexStringToBin:publicKey];
    
    TOX_ERR_BOOTSTRAP cError;
    
    bool result = tox_bootstrap(self.tox, cAddress, port, cPublicKey, &cError);
    
    [self fillError:error withCErrorBootstrap:cError];
    
    free(cPublicKey);
    
    return (BOOL)result;
}

- (BOOL)addTCPRelayWithHost:(NSString *)host port:(OCTToxPort)port publicKey:(NSString *)publicKey error:(NSError **)error
{
    NSParameterAssert(host);
    NSParameterAssert(publicKey);
    
    OCTLogInfo(@"add TCP relay with host %@ port %d publicKey %@", host, port, publicKey);
    
    const char *cAddress = host.UTF8String;
    uint8_t *cPublicKey = [OCTTox hexStringToBin:publicKey];
    
    TOX_ERR_BOOTSTRAP cError;
    
    bool result = tox_add_tcp_relay(self.tox, cAddress, port, cPublicKey, &cError);
    
    [self fillError:error withCErrorBootstrap:cError];
    
    free(cPublicKey);
    
    return (BOOL)result;
}

- (OCTToxFriendNumber)addFriendWithAddress:(NSString *)address message:(NSString *)message error:(NSError **)error
{
    NSParameterAssert(address);
    NSParameterAssert(message);
    NSAssert(address.length == kOCTToxAddressLength, @"Address must be kOCTToxAddressLength length");
    
    OCTLogVerbose(@"add friend with address.length %lu, message.length %lu", (unsigned long)address.length, (unsigned long)message.length);
    
    uint8_t *cAddress = [OCTTox hexStringToBin:address];
    const char *cMessage = [message cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    TOX_ERR_FRIEND_ADD cError;
    
    OCTToxFriendNumber result = tox_friend_add(self.tox, cAddress, (const uint8_t *)cMessage, length, &cError);
    
    free(cAddress);
    
    [self fillError:error withCErrorFriendAdd:cError];
    
    return result;
}

- (OCTToxFriendNumber)addFriendWithNoRequestWithPublicKey:(NSString *)publicKey error:(NSError **)error
{
    NSParameterAssert(publicKey);
    NSAssert(publicKey.length == kOCTToxPublicKeyLength, @"Public key must be kOCTToxPublicKeyLength length");
    
    OCTLogVerbose(@"add friend with no request and publicKey.length %lu", (unsigned long)publicKey.length);
    
    uint8_t *cPublicKey = [OCTTox hexStringToBin:publicKey];
    
    TOX_ERR_FRIEND_ADD cError;
    
    OCTToxFriendNumber result = tox_friend_add_norequest(self.tox, cPublicKey, &cError);
    
    free(cPublicKey);
    
    [self fillError:error withCErrorFriendAdd:cError];
    
    return result;
}

- (BOOL)deleteFriendWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_DELETE cError;
    
    bool result = tox_friend_delete(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendDelete:cError];
    
    OCTLogVerbose(@"deleting friend with friendNumber %d, result %d", friendNumber, (result == 0));
    
    return (BOOL)result;
}

- (OCTToxFriendNumber)friendNumberWithPublicKey:(NSString *)publicKey error:(NSError **)error
{
    NSParameterAssert(publicKey);
    NSAssert(publicKey.length == kOCTToxPublicKeyLength, @"Public key must be kOCTToxPublicKeyLength length");
    
    OCTLogVerbose(@"get friend number with publicKey.length %lu", (unsigned long)publicKey.length);
    
    uint8_t *cPublicKey = [OCTTox hexStringToBin:publicKey];
    
    TOX_ERR_FRIEND_BY_PUBLIC_KEY cError;
    
    OCTToxFriendNumber result = tox_friend_by_public_key(self.tox, cPublicKey, &cError);
    
    free(cPublicKey);
    
    [self fillError:error withCErrorFriendByPublicKey:cError];
    
    return result;
}

- (NSString *)publicKeyFromFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    OCTLogVerbose(@"get public key from friend number %d", friendNumber);
    
    uint8_t *cPublicKey = malloc(TOX_PUBLIC_KEY_SIZE);
    
    TOX_ERR_FRIEND_GET_PUBLIC_KEY cError;
    
    bool result = tox_friend_get_public_key(self.tox, friendNumber, cPublicKey, &cError);
    
    NSString *publicKey = nil;
    
    if (result) {
        publicKey = [OCTTox binToHexString:cPublicKey length:TOX_PUBLIC_KEY_SIZE];
    }
    
    if (cPublicKey) {
        free(cPublicKey);
    }
    
    [self fillError:error withCErrorFriendGetPublicKey:cError];
    
    return publicKey;
}

- (BOOL)friendExistsWithFriendNumber:(OCTToxFriendNumber)friendNumber
{
    bool result = tox_friend_exists(self.tox, friendNumber);
    
    OCTLogVerbose(@"friend exists with friendNumber %d, result %d", friendNumber, result);
    
    return (BOOL)result;
}

- (NSDate *)friendGetLastOnlineWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_GET_LAST_ONLINE cError;
    
    uint64_t timestamp = tox_friend_get_last_online(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendGetLastOnline:cError];
    
    if (timestamp == UINT64_MAX) {
        return nil;
    }
    
    return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

- (OCTToxUserStatus)friendStatusWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_QUERY cError;
    
    TOX_USER_STATUS cStatus = tox_friend_get_status(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    return [self userStatusFromCUserStatus:cStatus];
}

- (OCTToxConnectionStatus)friendConnectionStatusWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_QUERY cError;
    
    TOX_CONNECTION cStatus = tox_friend_get_connection_status(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    return [self userConnectionStatusFromCUserStatus:cStatus];
}

- (OCTToxMessageId)sendMessageUsingOldVersionWithFriendNumber:(OCTToxFriendNumber)friendNumber
                                                         type:(OCTToxMessageType)type
                                                      message:(NSData *)message
                                                        error:(NSError **)error
{
    NSParameterAssert(message);
    
    uint8_t cMessage[message.length];
    [message getBytes:&cMessage length:message.length];
    
    TOX_ERR_FRIEND_SEND_MESSAGE cError;
    TOX_MESSAGE_TYPE cType;
    switch (type) {
        case OCTToxMessageTypeNormal:
            cType = TOX_MESSAGE_TYPE_NORMAL;
            break;
        case OCTToxMessageTypeAction:
            cType = TOX_MESSAGE_TYPE_ACTION;
            break;
        default:
            cType = TOX_MESSAGE_TYPE_NORMAL;
            break;
    }
    
    OCTToxMessageId result = tox_friend_send_message(self.tox, friendNumber, cType, cMessage, message.length, &cError);
    [self fillError:error withCErrorFriendSendMessage:cError];
    
    return result;
}

- (OCTToxMessageId)sendMessageWithFriendNumber:(OCTToxFriendNumber)friendNumber
                               type:(OCTToxMessageType)type
                          messageId:(OCTToxMessageId)messageId
                            message:(NSData *)message
                              error:(NSError **)error
{
    uint8_t cMessage[message.length];
    [message getBytes:&cMessage length:message.length];
    
    TOX_MESSAGE_TYPE cType;
    switch (type) {
        case OCTToxMessageTypeNormal:
            cType = TOX_MESSAGE_TYPE_NORMAL;
            break;
        case OCTToxMessageTypeAction:
            cType = TOX_MESSAGE_TYPE_ACTION;
            break;
        case OCTToxMessageTypeBot:
            cType = TOX_MESSAGE_TYPE_BOT;
            break;
        case OCTToxMessageTypeForward:
            cType = TOX_MESSAGE_TYPE_FORWARD;
            break;
        case OCTToxMessageTypeGroup:
            cType = TOX_MESSAGE_TYPE_GROUP;
            break;
        case OCTToxMessageTypeEcho:
            cType = TOX_MESSAGE_TYPE_ECHO;
            break;
        case OCTToxMessageTypeConfirm:
            cType = TOX_MESSAGE_TYPE_CONFIRM;
            break;
        case OCTToxMessageTypeAssist:
            cType = TOX_MESSAGE_TYPE_ASSIST;
            break;
        case OCTToxMessageTypeEnd:
            cType = TOX_MESSAGE_TYPE_END;
            break;
    }
    
    TOX_ERR_FRIEND_SEND_MESSAGE cError;
    
    if (cType == TOX_MESSAGE_TYPE_ASSIST) {
        OCTToxMessageId resultAssist = [self sendAssistToFriendNumber:friendNumber];
        return resultAssist;
    }
    
    if (cType == TOX_MESSAGE_TYPE_ECHO) {
        OCTToxMessageId resultRes = tox_friend_send_message_res(self.tox, friendNumber, (const uint8_t *)cMessage, message.length, &cError);
        [self fillError:error withCErrorFriendSendMessage:cError];
        return resultRes;
    }
    
    if (cType == TOX_MESSAGE_TYPE_CONFIRM) {
        OCTToxMessageId resultCfm = tox_friend_send_message_cfm(self.tox, friendNumber, (const uint8_t *)cMessage, message.length, &cError);
        [self fillError:error withCErrorFriendSendMessage:cError];
        return resultCfm;
    }
    
    NSParameterAssert(message);
    
    OCTToxMessageId result = tox_friend_send_message_req(self.tox, friendNumber, (const uint8_t *)cMessage, message.length, &cError);
    [self fillError:error withCErrorFriendSendMessage:cError];
    
    return result;
}

- (BOOL)setNickname:(NSString *)name error:(NSError **)error
{
    NSParameterAssert(name);
    
    const char *cName = [name cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    TOX_ERR_SET_INFO cError;
    
    bool result = tox_self_set_name(self.tox, (const uint8_t *)cName, length, &cError);
    
    [self fillError:error withCErrorSetInfo:cError];
    
    OCTLogInfo(@"set userName to %@, result %d", name, result);
    
    return (BOOL)result;
}

- (NSString *)userName
{
    size_t length = tox_self_get_name_size(self.tox);
    
    if (! length) {
        return nil;
    }
    
    uint8_t *cName = malloc(length);
    tox_self_get_name(self.tox, cName);
    
    NSString *name = [[NSString alloc] initWithBytes:cName length:length encoding:NSUTF8StringEncoding];
    
    free(cName);
    
    return name;
}

- (NSString *)friendNameWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_QUERY cError;
    size_t size = tox_friend_get_name_size(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    if (cError != TOX_ERR_FRIEND_QUERY_OK) {
        return nil;
    }
    
    uint8_t *cName = malloc(size);
    bool result = tox_friend_get_name(self.tox, friendNumber, cName, &cError);
    
    NSString *name = nil;
    
    if (result) {
        name = [[NSString alloc] initWithBytes:cName length:size encoding:NSUTF8StringEncoding];
    }
    
    if (cName) {
        free(cName);
    }
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    return name;
}

- (BOOL)setUserStatusMessage:(NSString *)statusMessage error:(NSError **)error
{
    NSParameterAssert(statusMessage);
    
    const char *cStatusMessage = [statusMessage cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = [statusMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    TOX_ERR_SET_INFO cError;
    
    bool result = tox_self_set_status_message(self.tox, (const uint8_t *)cStatusMessage, length, &cError);
    
    [self fillError:error withCErrorSetInfo:cError];
    
    OCTLogInfo(@"set user status message to %@, result %d", statusMessage, result);
    
    return (BOOL)result;
}

- (NSString *)userStatusMessage
{
    size_t length = tox_self_get_status_message_size(self.tox);
    
    if (! length) {
        return nil;
    }
    
    uint8_t *cBuffer = malloc(length);
    
    tox_self_get_status_message(self.tox, cBuffer);
    
    NSString *message = [[NSString alloc] initWithBytes:cBuffer length:length encoding:NSUTF8StringEncoding];
    free(cBuffer);
    
    return message;
}

- (NSString *)friendStatusMessageWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_QUERY cError;
    
    size_t size = tox_friend_get_status_message_size(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    if (cError != TOX_ERR_FRIEND_QUERY_OK) {
        return nil;
    }
    
    uint8_t *cBuffer = malloc(size);
    
    bool result = tox_friend_get_status_message(self.tox, friendNumber, cBuffer, &cError);
    
    NSString *message = nil;
    
    if (result) {
        message = [[NSString alloc] initWithBytes:cBuffer length:size encoding:NSUTF8StringEncoding];
    }
    
    if (cBuffer) {
        free(cBuffer);
    }
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    return message;
}

- (BOOL)setUserIsTyping:(BOOL)isTyping forFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_SET_TYPING cError;
    
    bool result = tox_self_set_typing(self.tox, friendNumber, (bool)isTyping, &cError);
    
    [self fillError:error withCErrorSetTyping:cError];
    
    OCTLogInfo(@"set user isTyping to %d for friend number %d, result %d", isTyping, friendNumber, result);
    
    return (BOOL)result;
}

- (BOOL)isFriendTypingWithFriendNumber:(OCTToxFriendNumber)friendNumber error:(NSError **)error
{
    TOX_ERR_FRIEND_QUERY cError;
    
    bool isTyping = tox_friend_get_typing(self.tox, friendNumber, &cError);
    
    [self fillError:error withCErrorFriendQuery:cError];
    
    return (BOOL)isTyping;
}

- (NSUInteger)friendsCount
{
    return tox_self_get_friend_list_size(self.tox);
}

- (NSArray *)friendsArray
{
    size_t count = tox_self_get_friend_list_size(self.tox);
    
    if (! count) {
        return @[];
    }
    
    size_t listSize = count * sizeof(uint32_t);
    uint32_t *cList = malloc(listSize);
    
    tox_self_get_friend_list(self.tox, cList);
    
    NSMutableArray *list = [NSMutableArray new];
    
    for (NSUInteger index = 0; index < count; index++) {
        int32_t friendId = cList[index];
        [list addObject:@(friendId)];
    }
    
    free(cList);
    
    OCTLogVerbose(@"friend array %@", list);
    
    return [list copy];
}

- (NSData *)hashData:(NSData *)data
{
    uint8_t *cHash = malloc(TOX_HASH_LENGTH);
    const uint8_t *cData = [data bytes];
    
    bool result = tox_hash(cHash, cData, (uint32_t)data.length);
    NSData *hash;
    
    if (result) {
        hash = [NSData dataWithBytes:cHash length:TOX_HASH_LENGTH];
    }
    
    if (cHash) {
        free(cHash);
    }
    
    OCTLogInfo(@"hash data result %@", hash);
    
    return hash;
}

- (BOOL)fileSendControlForFileNumber:(OCTToxFileNumber)fileNumber
                        friendNumber:(OCTToxFriendNumber)friendNumber
                             control:(OCTToxFileControl)control
                               error:(NSError **)error
{
    TOX_FILE_CONTROL cControl;
    
    switch (control) {
        case OCTToxFileControlResume:
            cControl = TOX_FILE_CONTROL_RESUME;
            break;
        case OCTToxFileControlPause:
            cControl = TOX_FILE_CONTROL_PAUSE;
            break;
        case OCTToxFileControlCancel:
            cControl = TOX_FILE_CONTROL_CANCEL;
            break;
    }
    
    TOX_ERR_FILE_CONTROL cError;
    
    bool result = tox_file_control(self.tox, friendNumber, fileNumber, cControl, &cError);
    
    [self fillError:error withCErrorFileControl:cError];
    
    return (BOOL)result;
}

- (BOOL)fileSeekForFileNumber:(OCTToxFileNumber)fileNumber
                 friendNumber:(OCTToxFriendNumber)friendNumber
                     position:(OCTToxFileSize)position
                        error:(NSError **)error
{
    TOX_ERR_FILE_SEEK cError;
    
    bool result = tox_file_seek(self.tox, friendNumber, fileNumber, position, &cError);
    
    [self fillError:error withCErrorFileSeek:cError];
    
    return (BOOL)result;
}

- (NSData *)fileGetFileIdForFileNumber:(OCTToxFileNumber)fileNumber
                          friendNumber:(OCTToxFriendNumber)friendNumber
                                 error:(NSError **)error
{
    uint8_t *cFileId = malloc(kOCTToxFileIdLength);
    TOX_ERR_FILE_GET cError;
    
    bool result = tox_file_get_file_id(self.tox, friendNumber, fileNumber, cFileId, &cError);
    NSData *fileId;
    
    [self fillError:error withCErrorFileGet:cError];
    
    if (result) {
        fileId = [NSData dataWithBytes:cFileId length:kOCTToxFileIdLength];
    }
    
    if (cFileId) {
        free(cFileId);
    }
    
    return fileId;
}

- (OCTToxFileNumber)fileSendWithFriendNumber:(OCTToxFriendNumber)friendNumber
                                        kind:(OCTToxFileKind)kind
                                    fileSize:(OCTToxFileSize)fileSize
                                      fileId:(NSData *)fileId
                                    fileName:(NSData *)fileName
                                       error:(NSError **)error
{
    TOX_ERR_FILE_SEND cError;
    enum TOX_FILE_KIND cKind;
    const uint8_t *cFileId = NULL;
    const uint8_t *cFileName = NULL;
    
    switch (kind) {
        case OCTToxFileKindData:
            cKind = TOX_FILE_KIND_DATA;
            break;
        case OCTToxFileKindAvatar:
            cKind = TOX_FILE_KIND_AVATAR;
            break;
    }
    
    if (fileId.length) {
        cFileId = [fileId bytes];
    }
    
    if (fileName.length) {
        cFileName = (const uint8_t *)[fileName bytes];
    }
    
    OCTToxFileNumber result = tox_file_send(self.tox, friendNumber, cKind, fileSize, cFileId, cFileName, fileName.length, &cError);
    
    [self fillError:error withCErrorFileSend:cError];
    
    return result;
}

- (BOOL)fileSendChunkForFileNumber:(OCTToxFileNumber)fileNumber
                      friendNumber:(OCTToxFriendNumber)friendNumber
                          position:(OCTToxFileSize)position
                              data:(NSData *)data
                             error:(NSError **)error
{
    TOX_ERR_FILE_SEND_CHUNK cError;
    const uint8_t *cData = [data bytes];
    
    bool result = tox_file_send_chunk(self.tox, friendNumber, fileNumber, position, cData, (uint32_t)data.length, &cError);
    
    [self fillError:error withCErrorFileSendChunk:cError];
    
    return (BOOL)result;
}

- (OCTToxMessageId)generateMessageId
{
    return tox_local_msg_id();
}

- (NSData *)encryptOfflineMessage:(OCTToxFriendNumber)friendNumber message:(NSString *)message
{
    const char *cMessage = [message cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    size_t enlength = CRYPTO_PUBLIC_KEY_SIZE + CRYPTO_NONCE_SIZE + length + CRYPTO_MAC_SIZE;
    uint8_t *encryptMessage = malloc(enlength);
    int len = tox_encrypt_offline_message(self.tox, friendNumber, (const uint8_t *)cMessage, length, encryptMessage);
    
    NSData *data = [NSData dataWithBytes:encryptMessage length:len];
    return data;
}

- (BOOL)sendAssistToFriendNumber:(OCTToxFriendNumber)friendNumber
{
    TOX_ERR_FRIEND_SEND_MESSAGE cError;
    bool result = tox_send_message_assist(self.tox, friendNumber, nil, 0, &cError);
    return (BOOL)result;
}

#pragma mark -  Private methods

- (void)updateTimerIntervalIfNeeded
{
    uint64_t nextIterate = tox_iteration_interval(self.tox) * USEC_PER_SEC;
    
    if (self.previousIterate == nextIterate) {
        return;
    }
    
    self.previousIterate = nextIterate;
    dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, nextIterate), nextIterate, nextIterate / 5);
}

- (void)setupCFunctions
{
    _tox_self_get_public_key = tox_self_get_public_key;
}

- (void)setupCallbacks
{
    tox_callback_self_connection_status(_tox, connectionStatusCallback);
    tox_callback_friend_name(_tox, friendNameCallback);
    tox_callback_friend_status_message(_tox, friendStatusMessageCallback);
    tox_callback_friend_status(_tox, friendStatusCallback);
    tox_callback_friend_connection_status(_tox, friendConnectionStatusCallback);
    tox_callback_friend_typing(_tox, friendTypingCallback);
    tox_callback_friend_read_receipt(_tox, friendReadReceiptCallback);
    tox_callback_friend_request(_tox, friendRequestCallback);
    tox_callback_friend_message(_tox, friendMessageCallback);
    tox_callback_file_recv_control(_tox, fileReceiveControlCallback);
    tox_callback_file_chunk_request(_tox, fileChunkRequestCallback);
    tox_callback_file_recv(_tox, fileReceiveCallback);
    tox_callback_file_recv_chunk(_tox, fileReceiveChunkCallback);
    
    tox_callback_friend_message_req(_tox, friendMessageReqCallback);
    tox_callback_friend_message_res(_tox, friendMessageResCallback);
    tox_callback_friend_message_cfm(_tox, friendMessageConfirmCallback);
    tox_callback_assist_echo_message(_tox, assistMessageEchoCallback);
}

- (OCTToxUserStatus)userStatusFromCUserStatus:(TOX_USER_STATUS)cStatus
{
    switch (cStatus) {
        case TOX_USER_STATUS_NONE:
            return OCTToxUserStatusNone;
        case TOX_USER_STATUS_AWAY:
            return OCTToxUserStatusAway;
        case TOX_USER_STATUS_BUSY:
            return OCTToxUserStatusBusy;
    }
}

- (OCTToxConnectionStatus)userConnectionStatusFromCUserStatus:(TOX_CONNECTION)cStatus
{
    switch (cStatus) {
        case TOX_CONNECTION_NONE:
            return OCTToxConnectionStatusNone;
        case TOX_CONNECTION_TCP:
            return OCTToxConnectionStatusTCP;
        case TOX_CONNECTION_UDP:
            return OCTToxConnectionStatusUDP;
    }
}

- (OCTToxMessageType)messageTypeFromCMessageType:(TOX_MESSAGE_TYPE)cType
{
    switch (cType) {
        case TOX_MESSAGE_TYPE_NORMAL:
            return OCTToxMessageTypeNormal;
        case TOX_MESSAGE_TYPE_ACTION:
            return OCTToxMessageTypeAction;
        case TOX_MESSAGE_TYPE_BOT:
            return OCTToxMessageTypeBot;
        case TOX_MESSAGE_TYPE_GROUP:
            return OCTToxMessageTypeGroup;
        case TOX_MESSAGE_TYPE_FORWARD:
            return OCTToxMessageTypeForward;
        case TOX_MESSAGE_TYPE_ECHO:
            return OCTToxMessageTypeEcho;
        case TOX_MESSAGE_TYPE_CONFIRM:
            return OCTToxMessageTypeConfirm;
        case TOX_MESSAGE_TYPE_ASSIST:
            return OCTToxMessageTypeAssist;
        case TOX_MESSAGE_TYPE_END:
            return OCTToxMessageTypeEnd;
    }
}

- (OCTToxFileControl)fileControlFromCFileControl:(TOX_FILE_CONTROL)cControl
{
    switch (cControl) {
        case TOX_FILE_CONTROL_RESUME:
            return OCTToxFileControlResume;
        case TOX_FILE_CONTROL_PAUSE:
            return OCTToxFileControlPause;
        case TOX_FILE_CONTROL_CANCEL:
            return OCTToxFileControlCancel;
    }
}

- (BOOL)fillError:(NSError **)error withCErrorInit:(TOX_ERR_NEW)cError
{
    if (! error || (cError == TOX_ERR_NEW_OK)) {
        return NO;
    }
    
    OCTToxErrorInitCode code = OCTToxErrorInitCodeUnknown;
    NSString *description = @"Cannot initialize Tox";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_NEW_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_NEW_NULL:
            code = OCTToxErrorInitCodeUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_NEW_MALLOC:
            code = OCTToxErrorInitCodeMemoryError;
            failureReason = @"Not enough memory";
            break;
        case TOX_ERR_NEW_PORT_ALLOC:
            code = OCTToxErrorInitCodePortAlloc;
            failureReason = @"Cannot bint to a port";
            break;
        case TOX_ERR_NEW_PROXY_BAD_TYPE:
            code = OCTToxErrorInitCodeProxyBadType;
            failureReason = @"Proxy type is invalid";
            break;
        case TOX_ERR_NEW_PROXY_BAD_HOST:
            code = OCTToxErrorInitCodeProxyBadHost;
            failureReason = @"Proxy host is invalid";
            break;
        case TOX_ERR_NEW_PROXY_BAD_PORT:
            code = OCTToxErrorInitCodeProxyBadPort;
            failureReason = @"Proxy port is invalid";
            break;
        case TOX_ERR_NEW_PROXY_NOT_FOUND:
            code = OCTToxErrorInitCodeProxyNotFound;
            failureReason = @"Proxy host could not be resolved";
            break;
        case TOX_ERR_NEW_LOAD_ENCRYPTED:
            code = OCTToxErrorInitCodeEncrypted;
            failureReason = @"Tox save is encrypted";
            break;
        case TOX_ERR_NEW_LOAD_BAD_FORMAT:
            code = OCTToxErrorInitCodeLoadBadFormat;
            failureReason = @"Tox save is corrupted";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorBootstrap:(TOX_ERR_BOOTSTRAP)cError
{
    if (! error || (cError == TOX_ERR_BOOTSTRAP_OK)) {
        return NO;
    }
    
    OCTToxErrorBootstrapCode code = OCTToxErrorBootstrapCodeUnknown;
    NSString *description = @"Cannot bootstrap with specified node";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_BOOTSTRAP_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_BOOTSTRAP_NULL:
            code = OCTToxErrorBootstrapCodeUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_BOOTSTRAP_BAD_HOST:
            code = OCTToxErrorBootstrapCodeBadHost;
            failureReason = @"The host could not be resolved to an IP address, or the IP address passed was invalid";
            break;
        case TOX_ERR_BOOTSTRAP_BAD_PORT:
            code = OCTToxErrorBootstrapCodeBadPort;
            failureReason = @"The port passed was invalid";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendAdd:(TOX_ERR_FRIEND_ADD)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_ADD_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendAdd code = OCTToxErrorFriendAddUnknown;
    NSString *description = @"Cannot add friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_ADD_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_ADD_NULL:
            code = OCTToxErrorFriendAddUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_FRIEND_ADD_TOO_LONG:
            code = OCTToxErrorFriendAddTooLong;
            failureReason = @"The message is too long";
            break;
        case TOX_ERR_FRIEND_ADD_NO_MESSAGE:
            code = OCTToxErrorFriendAddNoMessage;
            failureReason = @"No message specified";
            break;
        case TOX_ERR_FRIEND_ADD_OWN_KEY:
            code = OCTToxErrorFriendAddOwnKey;
            failureReason = @"Cannot add own address";
            break;
        case TOX_ERR_FRIEND_ADD_ALREADY_SENT:
            code = OCTToxErrorFriendAddAlreadySent;
            failureReason = @"The request was already sent";
            break;
        case TOX_ERR_FRIEND_ADD_BAD_CHECKSUM:
            code = OCTToxErrorFriendAddBadChecksum;
            failureReason = @"Bad checksum";
            break;
        case TOX_ERR_FRIEND_ADD_SET_NEW_NOSPAM:
            code = OCTToxErrorFriendAddSetNewNospam;
            failureReason = @"The no spam value is outdated";
            break;
        case TOX_ERR_FRIEND_ADD_MALLOC:
            code = OCTToxErrorFriendAddMalloc;
            failureReason = nil;
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendDelete:(TOX_ERR_FRIEND_DELETE)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_DELETE_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendDelete code = OCTToxErrorFriendDeleteNotFound;
    NSString *description = @"Cannot delete friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_DELETE_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_DELETE_FRIEND_NOT_FOUND:
            code = OCTToxErrorFriendDeleteNotFound;
            failureReason = @"Friend not found";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendByPublicKey:(TOX_ERR_FRIEND_BY_PUBLIC_KEY)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_BY_PUBLIC_KEY_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendByPublicKey code = OCTToxErrorFriendByPublicKeyUnknown;
    NSString *description = @"Cannot get friend by public key";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_BY_PUBLIC_KEY_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_BY_PUBLIC_KEY_NULL:
            code = OCTToxErrorFriendByPublicKeyUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_FRIEND_BY_PUBLIC_KEY_NOT_FOUND:
            code = OCTToxErrorFriendByPublicKeyNotFound;
            failureReason = @"No friend with the given Public Key exists on the friend list";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendGetPublicKey:(TOX_ERR_FRIEND_GET_PUBLIC_KEY)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_GET_PUBLIC_KEY_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendGetPublicKey code = OCTToxErrorFriendGetPublicKeyFriendNotFound;
    NSString *description = @"Cannot get public key of a friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_GET_PUBLIC_KEY_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_GET_PUBLIC_KEY_FRIEND_NOT_FOUND:
            code = OCTToxErrorFriendGetPublicKeyFriendNotFound;
            failureReason = @"Friend not found";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorSetInfo:(TOX_ERR_SET_INFO)cError
{
    if (! error || (cError == TOX_ERR_SET_INFO_OK)) {
        return NO;
    }
    
    OCTToxErrorSetInfoCode code = OCTToxErrorSetInfoCodeUnknow;
    NSString *description = @"Cannot set user info";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_SET_INFO_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_SET_INFO_NULL:
            code = OCTToxErrorSetInfoCodeUnknow;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_SET_INFO_TOO_LONG:
            code = OCTToxErrorSetInfoCodeTooLong;
            failureReason = @"Specified string is too long";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendGetLastOnline:(TOX_ERR_FRIEND_GET_LAST_ONLINE)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_GET_LAST_ONLINE_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendGetLastOnline code;
    NSString *description = @"Cannot get last online of a friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_GET_LAST_ONLINE_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_GET_LAST_ONLINE_FRIEND_NOT_FOUND:
            code = OCTToxErrorFriendGetLastOnlineFriendNotFound;
            failureReason = @"Friend not found";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendQuery:(TOX_ERR_FRIEND_QUERY)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_QUERY_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendQuery code = OCTToxErrorFriendQueryUnknown;
    NSString *description = @"Cannot perform friend query";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_QUERY_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_QUERY_NULL:
            code = OCTToxErrorFriendQueryUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND:
            code = OCTToxErrorFriendQueryFriendNotFound;
            failureReason = @"Friend not found";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorSetTyping:(TOX_ERR_SET_TYPING)cError
{
    if (! error || (cError == TOX_ERR_SET_TYPING_OK)) {
        return NO;
    }
    
    OCTToxErrorSetTyping code = OCTToxErrorSetTypingFriendNotFound;
    NSString *description = @"Cannot set typing status for a friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_SET_TYPING_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_SET_TYPING_FRIEND_NOT_FOUND:
            code = OCTToxErrorSetTypingFriendNotFound;
            failureReason = @"Friend not found";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFriendSendMessage:(TOX_ERR_FRIEND_SEND_MESSAGE)cError
{
    if (! error || (cError == TOX_ERR_FRIEND_SEND_MESSAGE_OK)) {
        return NO;
    }
    
    OCTToxErrorFriendSendMessage code = OCTToxErrorFriendSendMessageUnknown;
    NSString *description = @"Cannot send message to a friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FRIEND_SEND_MESSAGE_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FRIEND_SEND_MESSAGE_NULL:
            code = OCTToxErrorFriendSendMessageUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_FOUND:
            code = OCTToxErrorFriendSendMessageFriendNotFound;
            failureReason = @"Friend not found";
            break;
        case TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_CONNECTED:
            code = OCTToxErrorFriendSendMessageFriendNotConnected;
            failureReason = @"Friend not connected";
            break;
        case TOX_ERR_FRIEND_SEND_MESSAGE_SENDQ:
            code = OCTToxErrorFriendSendMessageAlloc;
            failureReason = @"Allocation error";
            break;
        case TOX_ERR_FRIEND_SEND_MESSAGE_TOO_LONG:
            code = OCTToxErrorFriendSendMessageTooLong;
            failureReason = @"Message is too long";
            break;
        case TOX_ERR_FRIEND_SEND_MESSAGE_EMPTY:
            code = OCTToxErrorFriendSendMessageEmpty;
            failureReason = @"Message is empty";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFileControl:(TOX_ERR_FILE_CONTROL)cError
{
    if (! error || (cError == TOX_ERR_FILE_CONTROL_OK)) {
        return NO;
    }
    
    OCTToxErrorFileControl code;
    NSString *description = @"Cannot send file control to a friend";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FILE_CONTROL_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FILE_CONTROL_FRIEND_NOT_FOUND:
            code = OCTToxErrorFileControlFriendNotFound;
            failureReason = @"Friend not found";
            break;
        case TOX_ERR_FILE_CONTROL_FRIEND_NOT_CONNECTED:
            code = OCTToxErrorFileControlFriendNotConnected;
            failureReason = @"Friend is not connected";
            break;
        case TOX_ERR_FILE_CONTROL_NOT_FOUND:
            code = OCTToxErrorFileControlNotFound;
            failureReason = @"No file transfer with given file number found";
            break;
        case TOX_ERR_FILE_CONTROL_NOT_PAUSED:
            code = OCTToxErrorFileControlNotPaused;
            failureReason = @"Resume was send, but file transfer if running normally";
            break;
        case TOX_ERR_FILE_CONTROL_DENIED:
            code = OCTToxErrorFileControlDenied;
            failureReason = @"Cannot resume, file transfer was paused by the other party.";
            break;
        case TOX_ERR_FILE_CONTROL_ALREADY_PAUSED:
            code = OCTToxErrorFileControlAlreadyPaused;
            failureReason = @"File is already paused";
            break;
        case TOX_ERR_FILE_CONTROL_SENDQ:
            code = OCTToxErrorFileControlSendq;
            failureReason = @"Packet queue is full";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFileSeek:(TOX_ERR_FILE_SEEK)cError
{
    if (! error || (cError == TOX_ERR_FILE_SEEK_OK)) {
        return NO;
    }
    
    OCTToxErrorFileSeek code;
    NSString *description = @"Cannot perform file seek";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FILE_SEEK_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FILE_SEEK_FRIEND_NOT_FOUND:
            code = OCTToxErrorFileSeekFriendNotFound;
            failureReason = @"Friend not found";
            break;
        case TOX_ERR_FILE_SEEK_FRIEND_NOT_CONNECTED:
            code = OCTToxErrorFileSeekFriendNotConnected;
            failureReason = @"Friend is not connected";
            break;
        case TOX_ERR_FILE_SEEK_NOT_FOUND:
            code = OCTToxErrorFileSeekNotFound;
            failureReason = @"No file transfer with given file number found";
            break;
        case TOX_ERR_FILE_SEEK_DENIED:
            code = OCTToxErrorFileSeekDenied;
            failureReason = @"File was not in a state where it could be seeked";
            break;
        case TOX_ERR_FILE_SEEK_INVALID_POSITION:
            code = OCTToxErrorFileSeekInvalidPosition;
            failureReason = @"Seek position was invalid";
            break;
        case TOX_ERR_FILE_SEEK_SENDQ:
            code = OCTToxErrorFileSeekSendq;
            failureReason = @"Packet queue is full";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFileGet:(TOX_ERR_FILE_GET)cError
{
    if (! error || (cError == TOX_ERR_FILE_GET_OK)) {
        return NO;
    }
    
    OCTToxErrorFileGet code;
    NSString *description = @"Cannot get file id";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FILE_GET_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FILE_GET_NULL:
            code = OCTToxErrorFileGetInternal;
            failureReason = @"Interval error";
            break;
        case TOX_ERR_FILE_GET_FRIEND_NOT_FOUND:
            code = OCTToxErrorFileGetFriendNotFound;
            failureReason = @"Friend not found";
            break;
        case TOX_ERR_FILE_GET_NOT_FOUND:
            code = OCTToxErrorFileGetNotFound;
            failureReason = @"No file transfer with given file number found";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFileSend:(TOX_ERR_FILE_SEND)cError
{
    if (! error || (cError == TOX_ERR_FILE_SEND_OK)) {
        return NO;
    }
    
    OCTToxErrorFileSend code;
    NSString *description = @"Cannot send file";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FILE_SEND_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FILE_SEND_NULL:
            code = OCTToxErrorFileSendUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_FILE_SEND_FRIEND_NOT_FOUND:
            code = OCTToxErrorFileSendFriendNotFound;
            failureReason = @"Friend not found";
            break;
        case TOX_ERR_FILE_SEND_FRIEND_NOT_CONNECTED:
            code = OCTToxErrorFileSendFriendNotConnected;
            failureReason = @"Friend not connected";
            break;
        case TOX_ERR_FILE_SEND_NAME_TOO_LONG:
            code = OCTToxErrorFileSendNameTooLong;
            failureReason = @"File name is too long";
            break;
        case TOX_ERR_FILE_SEND_TOO_MANY:
            code = OCTToxErrorFileSendTooMany;
            failureReason = @"Too many ongoing transfers with friend";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

- (BOOL)fillError:(NSError **)error withCErrorFileSendChunk:(TOX_ERR_FILE_SEND_CHUNK)cError
{
    if (! error || (cError == TOX_ERR_FILE_SEND_CHUNK_OK)) {
        return NO;
    }
    
    OCTToxErrorFileSendChunk code;
    NSString *description = @"Cannot send chunk of file";
    NSString *failureReason = nil;
    
    switch (cError) {
        case TOX_ERR_FILE_SEND_CHUNK_OK:
            NSAssert(NO, @"We shouldn't be here");
            return NO;
        case TOX_ERR_FILE_SEND_CHUNK_NULL:
            code = OCTToxErrorFileSendChunkUnknown;
            failureReason = @"Unknown error occured";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_FRIEND_NOT_FOUND:
            code = OCTToxErrorFileSendChunkFriendNotFound;
            failureReason = @"Friend not found";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_FRIEND_NOT_CONNECTED:
            code = OCTToxErrorFileSendChunkFriendNotConnected;
            failureReason = @"Friend not connected";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_NOT_FOUND:
            code = OCTToxErrorFileSendChunkNotFound;
            failureReason = @"No file transfer with given file number found";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_NOT_TRANSFERRING:
            code = OCTToxErrorFileSendChunkNotTransferring;
            failureReason = @"Wrong file transferring state";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_INVALID_LENGTH:
            code = OCTToxErrorFileSendChunkInvalidLength;
            failureReason = @"Invalid chunk length";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_SENDQ:
            code = OCTToxErrorFileSendChunkSendq;
            failureReason = @"Packet queue is full";
            break;
        case TOX_ERR_FILE_SEND_CHUNK_WRONG_POSITION:
            code = OCTToxErrorFileSendChunkWrongPosition;
            failureReason = @"Wrong position in file";
            break;
    }
    
    *error = [OCTTox createErrorWithCode:code description:description failureReason:failureReason];
    
    return YES;
}

+ (NSError *)createErrorWithCode:(NSUInteger)code
                     description:(NSString *)description
                   failureReason:(NSString *)failureReason
{
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    
    if (description) {
        userInfo[NSLocalizedDescriptionKey] = description;
    }
    
    if (failureReason) {
        userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
    }
    
    return [NSError errorWithDomain:kOCTToxErrorDomain code:code userInfo:userInfo];
}

+ (NSString *)binToHexString:(uint8_t *)bin length:(NSUInteger)length
{
    NSMutableString *string = [NSMutableString stringWithCapacity:length];
    
    for (NSUInteger idx = 0; idx < length; ++idx) {
        [string appendFormat:@"%02X", bin[idx]];
    }
    
    return [string copy];
}

// You are responsible for freeing the return value!
+ (uint8_t *)hexStringToBin:(NSString *)string
{
    // byte is represented by exactly 2 hex digits, so lenth of binary string
    // is half of that of the hex one. only hex string with even length
    // valid. the more proper implementation would be to check if strlen(hex_string)
    // is odd and return error code if it is. we assume strlen is even. if it's not
    // then the last byte just won't be written in 'ret'.
    
    char *hex_string = (char *)string.UTF8String;
    size_t i, len = strlen(hex_string) / 2;
    uint8_t *ret = malloc(len);
    char *pos = hex_string;
    
    for (i = 0; i < len; ++i, pos += 2) {
        sscanf(pos, "%2hhx", &ret[i]);
    }
    
    return ret;
}

@end

#pragma mark -  Callbacks

void logCallback(Tox *tox,
                 TOX_LOG_LEVEL level,
                 const char *file,
                 uint32_t line,
                 const char *func,
                 const char *message,
                 void *user_data)
{
    switch (level) {
        case TOX_LOG_LEVEL_TRACE:
            OCTLogCCVerbose(@"TRACE: <toxcore: %s:%u, %s> %s", file, line, func, message);
            break;
        case TOX_LOG_LEVEL_DEBUG:
            OCTLogCCDebug(@"DEBUG: <toxcore: %s:%u, %s> %s", file, line, func, message);
            break;
        case TOX_LOG_LEVEL_INFO:
            OCTLogCCInfo(@"INFO: <toxcore: %s:%u, %s> %s", file, line, func, message);
            break;
        case TOX_LOG_LEVEL_WARNING:
            OCTLogCCWarn(@"WARNING: <toxcore: %s:%u, %s> %s", file, line, func, message);
            break;
        case TOX_LOG_LEVEL_ERROR:
            OCTLogCCError(@"ERROR: <toxcore: %s:%u, %s> %s", file, line, func, message);
            break;
    }
}

void connectionStatusCallback(Tox *cTox, TOX_CONNECTION cStatus, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTToxConnectionStatus status = [tox userConnectionStatusFromCUserStatus:cStatus];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"connectionStatusCallback with status %lu", tox, (unsigned long)status);
        
        if ([tox.delegate respondsToSelector:@selector(tox:connectionStatus:)]) {
            [tox.delegate tox:tox connectionStatus:status];
        }
    });
}

void friendNameCallback(Tox *cTox, uint32_t friendNumber, const uint8_t *cName, size_t length, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSString *name = [NSString stringWithCString:(const char *)cName encoding:NSUTF8StringEncoding];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"nameChangeCallback with name %@, friend number %d", tox, name, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:friendNameUpdate:friendNumber:)]) {
            [tox.delegate tox:tox friendNameUpdate:name friendNumber:friendNumber];
        }
    });
}

void friendStatusMessageCallback(Tox *cTox, uint32_t friendNumber, const uint8_t *cMessage, size_t length, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSString *message = [NSString stringWithCString:(const char *)cMessage encoding:NSUTF8StringEncoding];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"statusMessageCallback with status message %@, friend number %d", tox, message, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:friendStatusMessageUpdate:friendNumber:)]) {
            [tox.delegate tox:tox friendStatusMessageUpdate:message friendNumber:friendNumber];
        }
    });
}

void friendStatusCallback(Tox *cTox, uint32_t friendNumber, TOX_USER_STATUS cStatus, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTToxUserStatus status = [tox userStatusFromCUserStatus:cStatus];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"userStatusCallback with status %lu, friend number %d", tox, (unsigned long)status, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:friendStatusUpdate:friendNumber:)]) {
            [tox.delegate tox:tox friendStatusUpdate:status friendNumber:friendNumber];
        }
    });
}

void friendConnectionStatusCallback(Tox *cTox, uint32_t friendNumber, TOX_CONNECTION cStatus, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTToxConnectionStatus status = [tox userConnectionStatusFromCUserStatus:cStatus];
    
    OCTLogCInfo(@"connectionStatusCallback with status %lu, friendNumber %d", tox, (unsigned long)status, friendNumber);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([tox.delegate respondsToSelector:@selector(tox:friendConnectionStatusChanged:friendNumber:)]) {
            [tox.delegate tox:tox friendConnectionStatusChanged:status friendNumber:friendNumber];
        }
    });
}

void friendTypingCallback(Tox *cTox, uint32_t friendNumber, bool isTyping, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTLogCInfo(@"typingChangeCallback with isTyping %d, friend number %d", tox, isTyping, friendNumber);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([tox.delegate respondsToSelector:@selector(tox:friendIsTypingUpdate:friendNumber:)]) {
            [tox.delegate tox:tox friendIsTypingUpdate:(BOOL)isTyping friendNumber:friendNumber];
        }
    });
}

void friendReadReceiptCallback(Tox *cTox, uint32_t friendNumber, uint32_t messageId, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTLogCInfo(@"readReceiptCallback with message id %d, friendNumber %d", tox, messageId, friendNumber);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([tox.delegate respondsToSelector:@selector(tox:messageDelivered:friendNumber:)]) {
            [tox.delegate tox:tox messageDelivered:messageId friendNumber:friendNumber];
        }
    });
}

void friendRequestCallback(Tox *cTox, const uint8_t *cPublicKey, const uint8_t *cMessage, size_t length, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSString *publicKey = [OCTTox binToHexString:(uint8_t *)cPublicKey length:TOX_PUBLIC_KEY_SIZE];
    NSString *message = [[NSString alloc] initWithBytes:cMessage length:length encoding:NSUTF8StringEncoding];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"friendRequestCallback with publicKey %@, message %@", tox, publicKey, message);
        
        if ([tox.delegate respondsToSelector:@selector(tox:friendRequestWithMessage:publicKey:)]) {
            [tox.delegate tox:tox friendRequestWithMessage:message publicKey:publicKey];
        }
    });
}

void friendMessageCallback(
                           Tox *cTox,
                           uint32_t friendNumber,
                           TOX_MESSAGE_TYPE cType,
                           uint32_t time,
                           const uint8_t *cMessage,
                           size_t length,
                           void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTToxMessageType type = [tox messageTypeFromCMessageType:cType];
    NSData *message = [NSData dataWithBytes:cMessage length:length];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[Tox old version]friendMessageCallback with message %@, friend number %d", tox, message, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:friendMessage:type:friendNumber:time:)]) {
            [tox.delegate tox:tox friendMessage:message type:type friendNumber:friendNumber time:time];
        }
    });
}

void fileReceiveControlCallback(Tox *cTox, uint32_t friendNumber, OCTToxFileNumber fileNumber, TOX_FILE_CONTROL cControl, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTToxFileControl control = [tox fileControlFromCFileControl:cControl];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"fileReceiveControlCallback with friendNumber %d fileNumber %d controlType %lu",
                    tox, friendNumber, fileNumber, (unsigned long)control);
        
        if ([tox.delegate respondsToSelector:@selector(tox:fileReceiveControl:friendNumber:fileNumber:)]) {
            [tox.delegate tox:tox fileReceiveControl:control friendNumber:friendNumber fileNumber:fileNumber];
        }
    });
}

void fileChunkRequestCallback(Tox *cTox, uint32_t friendNumber, OCTToxFileNumber fileNumber, uint64_t position, size_t length, void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([tox.delegate respondsToSelector:@selector(tox:fileChunkRequestForFileNumber:friendNumber:position:length:)]) {
            [tox.delegate tox:tox fileChunkRequestForFileNumber:fileNumber
                 friendNumber:friendNumber
                     position:position
                       length:length];
        }
    });
}

void fileReceiveCallback(
                         Tox *cTox,
                         uint32_t friendNumber,
                         OCTToxFileNumber fileNumber,
                         enum TOX_FILE_KIND cKind,
                         uint64_t fileSize,
                         const uint8_t *cFileName,
                         size_t fileNameLength,
                         void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    OCTToxFileKind kind;
    
    switch (cKind) {
        case TOX_FILE_KIND_DATA:
            kind = OCTToxFileKindData;
            break;
        case TOX_FILE_KIND_AVATAR:
            kind = OCTToxFileKindAvatar;
            break;
    }
    
    NSData *fileName = [NSData dataWithBytes:cFileName length:fileNameLength];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"fileReceiveCallback with friendNumber %d fileNumber %d kind %ld fileSize %llu fileName %@",
                    tox, friendNumber, fileNumber, (long)kind, fileSize, fileName);
        
        if ([tox.delegate respondsToSelector:@selector(tox:fileReceiveForFileNumber:friendNumber:kind:fileSize:fileName:)]) {
            [tox.delegate tox:tox fileReceiveForFileNumber:fileNumber
                 friendNumber:friendNumber
                         kind:kind
                     fileSize:fileSize
                     fileName:fileName];
        }
    });
}

void fileReceiveChunkCallback(
                              Tox *cTox,
                              uint32_t friendNumber,
                              OCTToxFileNumber fileNumber,
                              uint64_t position,
                              const uint8_t *cData,
                              size_t length,
                              void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSData *chunk = nil;
    
    if (length) {
        chunk = [NSData dataWithBytes:cData length:length];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([tox.delegate respondsToSelector:@selector(tox:fileReceiveChunk:fileNumber:friendNumber:position:)]) {
            [tox.delegate tox:tox fileReceiveChunk:chunk fileNumber:fileNumber friendNumber:friendNumber position:position];
        }
    });
}

/* new message protocol */

void friendMessageReqCallback(Tox *cTox,
                              uint32_t friendNumber,
                              uint32_t time,
                              const uint8_t *cMessage,
                              size_t length,
                              void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSData *message = [NSData dataWithBytes:cMessage length:length];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"friendMessageReqCallback with message %@, friend number %d", tox, message, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:receivedMessage:length:friendNumber:time:)]) {
            [tox.delegate tox:tox receivedMessage:message length:length friendNumber:friendNumber time:time];
        }
    });
}

void friendMessageResCallback(Tox *cTox,
                              uint32_t friendNumber,
                              uint32_t time,
                              const uint8_t *cMessage,
                              size_t length,
                              void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSData *message = [NSData dataWithBytes:cMessage length:length];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"friendMessageResCallback with message %@, friend number %d", tox, message, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:receivedResponse:length:friendNumber:time:)]) {
            [tox.delegate tox:tox receivedResponse:message length:length friendNumber:friendNumber time:time];
        }
    });
}

void friendMessageConfirmCallback(Tox *cTox,
                              uint32_t friendNumber,
                              uint32_t time,
                              const uint8_t *cMessage,
                              size_t length,
                              void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    NSData *message = [NSData dataWithBytes:cMessage length:length];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        OCTLogCInfo(@"friendMessageConfirmCallback with message %@, friend number %d", tox, message, friendNumber);
        
        if ([tox.delegate respondsToSelector:@selector(tox:receivedConfirm:length:friendNumber:time:)]) {
            [tox.delegate tox:tox receivedConfirm:message length:length friendNumber:friendNumber time:time];
        }
    });
}

void assistMessageEchoCallback(Tox *cTox, uint32_t friendNumber, uint32_t version, const uint8_t *cMessage,
                           size_t length,  void *userData)
{
    OCTTox *tox = (__bridge OCTTox *)(userData);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"assistMessageEchoCallback with version %d, friend number %d", version, friendNumber);

        if ([tox.delegate respondsToSelector:@selector(tox:version:friendNumber:)]) {
            [tox.delegate tox:tox version:version friendNumber:friendNumber];
        }
    });
}
