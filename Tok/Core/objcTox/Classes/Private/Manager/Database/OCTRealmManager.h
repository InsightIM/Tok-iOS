// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

#import "OCTToxConstants.h"
#import "OCTManagerConstants.h"

@class OCTObject;
@class OCTFriend;
@class OCTChat;
@class OCTPeer;
@class OCTCall;
@class OCTMessageAbstract;
@class OCTSettingsStorageObject;
@class RLMResults;
@class RLMNotificationToken;

extern const uint64_t kCurrentSchemeVersion;

@interface OCTRealmManager : NSObject

/**
 * Storage with all objcTox settings.
 */
@property (strong, nonatomic, readonly) OCTSettingsStorageObject *settingsStorage;

/**
 * Migrate unencrypted database to encrypted one.
 *
 * @param databasePath Path to unencrypted database.
 * @param encryptionKey Key used to encrypt database.
 * @param error Error parameter will be filled in case of failure. It will contain RLMRealm or NSFileManager error.
 *
 * @return YES on success, NO on failure.
 */
+ (BOOL)migrateToEncryptedDatabase:(NSString *)databasePath
                     encryptionKey:(NSData *)encryptionKey
                             error:(NSError **)error;

/**
 * Create RealmManager.
 *
 * @param fileURL path to Realm file. File will be created if it doesn't exist.
 * @param encryptionKey A 64-byte key to use to encrypt the data, or nil if encryption is not enabled.
 */
- (instancetype)initWithDatabaseFileURL:(NSURL *)fileURL encryptionKey:(NSData *)encryptionKey;

- (RLMRealm *)database;

- (void)refresh;

#pragma mark -  Basic methods

- (id)objectWithUniqueIdentifier:(NSString *)uniqueIdentifier class:(Class)class;

- (RLMResults *)objectsWithClass:(Class)class predicate:(NSPredicate *)predicate;
- (RLMResults *)objectsWithClass:(Class)class predicate:(NSPredicate *)predicate db:(RLMRealm *)db;

- (void)addObjects:(NSArray<OCTObject *> *)objects;
- (void)addObject:(OCTObject *)object;
- (void)addObject:(OCTObject *)object withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens;
- (void)deleteObject:(OCTObject *)object;
- (void)deleteObject:(OCTObject *)object db:(RLMRealm *)db;

/*
 * All realm objects should be updated ONLY using following two methods.
 *
 * Specified object will be passed in block.
 */
- (void)updateObject:(OCTObject *)object withBlock:(void (^)(id theObject))updateBlock;
- (void)updateObject:(OCTObject *)object db:(RLMRealm *)db withBlock:(void (^)(id theObject))updateBlock;
- (void)updateObject:(OCTObject *)object withBlock:(void (^)(id theObject))updateBlock  withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens;

- (void)updateObjectsWithClass:(Class)class
                     predicate:(NSPredicate *)predicate
                   updateBlock:(void (^)(id theObject))updateBlock;
- (void)updateObjectsWithClass:(Class)class predicate:(NSPredicate *)predicate db:(RLMRealm *)db updateBlock:(void (^)(id theObject))updateBlock;

#pragma mark -  Other methods
- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey db:(RLMRealm *)db;

- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey;
- (OCTFriend *)friendWithPublicKey:(NSString *)publicKey friendState:(NSInteger)friendState;
- (OCTPeer *)peerWithPeerPK:(NSString *)publicKey;
- (OCTPeer *)peerWithPeerPK:(NSString *)publicKey groupNumber:(NSInteger)groupNumber;
- (void)addPeersWithGroupNumber:(NSInteger)groupNumber peers:(NSArray<OCTPeer *> *)newPeers ownerPublicKey:(NSString *)ownerPublicKey;
- (OCTChat *)getChatWithFriend:(OCTFriend *)friend;
- (OCTChat *)getOrCreateChatWithFriend:(OCTFriend *)friend;

- (OCTChat *)getGroupChatWithGroupNumber:(NSInteger)groupNumber;
- (OCTChat *)getOrCreateChatWithGroupNumber:(NSInteger)groupNumber;
- (OCTCall *)createCallWithChat:(OCTChat *)chat status:(OCTCallStatus)status;

/**
 * Gets the current call for the chat if and only if it exists.
 * This will not create a call object.
 * @param chat The chat that is related to the call.
 * @return A call object if it exists, nil if no call is session for this call.
 */
- (OCTCall *)getCurrentCallForChat:(OCTChat *)chat;

- (void)markChatMessagesAsRead:(OCTChat *)chat;
- (void)markChatMessagesAsRead:(NSString *)chatId db:(RLMRealm *)db;
- (void)removeMessages:(NSArray<OCTMessageAbstract *> *)messages withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens;
- (void)removeAllMessagesInChat:(OCTChat *)chat removeChat:(BOOL)removeChat;

/**
 * Converts all the OCTCalls to OCTMessageCalls.
 * Only use this when first starting the app or during termination.
 */
- (void)convertAllCallsToMessages;

- (OCTMessageAbstract *)addMessageWithText:(NSString *)text
                                      type:(OCTToxMessageType)type
                                      chat:(OCTChat *)chat
                                    sender:(OCTObject *)sender
                                 messageId:(OCTToxMessageId)messageId
                              dateInterval:(NSTimeInterval)dateInterval
                                    status:(NSInteger)status
                          withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens;

- (OCTMessageAbstract *)createMessageWithText:(NSString *)text
                                         type:(OCTToxMessageType)type
                                         chat:(OCTChat *)chat
                                       sender:(OCTObject *)sender
                                    messageId:(OCTToxMessageId)messageId
                                 dateInterval:(NSTimeInterval)dateInterval
                                       status:(NSInteger)status
                                        realm:(RLMRealm *)realm;

- (OCTMessageAbstract *)addOtherMessageWithText:(NSString *)text
                                           type:(OCTToxMessageType)type
                                           chat:(OCTChat *)chat
                                    messageType:(NSInteger)messageType
                                      messageId:(OCTToxMessageId)messageId;

- (OCTMessageAbstract *)addMessageWithFileNumber:(OCTToxFileNumber)fileNumber
                                        fileType:(OCTMessageFileType)fileType
                                        fileSize:(OCTToxFileSize)fileSize
                                        fileName:(NSString *)fileName
                                        filePath:(NSString *)filePath
                                         fileUTI:(NSString *)fileUTI
                                            chat:(OCTChat *)chat
                                          sender:(OCTObject *)sender
                                    dateInterval:(NSTimeInterval)dateInterval
                                       isOffline:(BOOL)isOffline
                                       messageId:(OCTToxMessageId)messageId
                                          opened:(BOOL)opened;

- (OCTMessageAbstract *)addMessageCall:(OCTCall *)call;

- (BOOL)checkMessageIsExisted:(OCTToxMessageId)messageId chat:(OCTChat *)chat checkFile:(BOOL)checkFile;

- (BOOL)friendAcceptRequest:(NSString *)publicKey;
- (BOOL)friendAcceptRequest:(NSString *)publicKey db:(RLMRealm *)db;

- (void)addFriendRequestWithMessage:(NSString *)message publicKey:(NSString *)publicKey isOutgoing:(BOOL)isOutgoing;

#pragma mark - custom realm

- (void)updateObject:(OCTObject *)object realm:(RLMRealm *)realm withBlock:(void (^)(id theObject))updateBlock;
- (OCTChat *)getOrCreateChatWithGroupNumber:(NSInteger)groupNumber realm:(RLMRealm *)realm;
- (OCTMessageAbstract *)checkMessageIsExisted:(OCTToxMessageId)messageId chat:(OCTChat *)chat checkFile:(BOOL)checkFile realm:(RLMRealm *)realm;
- (OCTPeer *)peerWithPeerPK:(NSString *)publicKey groupNumber:(NSInteger)groupNumber realm:(RLMRealm *)realm;
- (OCTChat *)getGroupChatWithGroupNumber:(NSInteger)groupNumber realm:(RLMRealm *)realm;
- (OCTMessageAbstract *)addOtherMessageWithText:(NSString *)text
                                           type:(OCTToxMessageType)type
                                           chat:(OCTChat *)chat
                                    messageType:(NSInteger)messageType
                                      messageId:(OCTToxMessageId)messageId
                                          realm:(RLMRealm *)realm;

@end
