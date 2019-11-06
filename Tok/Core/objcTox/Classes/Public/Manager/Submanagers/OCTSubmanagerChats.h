// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

#import "OCTToxConstants.h"

@class OCTChat;
@class OCTFriend;
@class OCTMessageAbstract;
@class OCTPeer;
@class RLMNotificationToken;

typedef void (^OCTGroupMessageSuccessBlock)(OCTChat *chat);
typedef void (^OCTGroupMessageFailureBlock)(NSError *error);

@protocol OCTSubmanagerChats <NSObject>

/**
 * Searches for a chat with specific friend. If chat is not found returns nil.
 *
 * @param friend Friend to get chat with.
 *
 * @return Chat with specific friend.
 */
- (OCTChat *)getChatWithFriend:(OCTFriend *)friend;

/**
 * Searches for a chat with specific friend. If chat is not found creates one and returns it.
 *
 * @param friend Friend to get/create chat with.
 *
 * @return Chat with specific friend.
 */
//- (OCTChat *)getOrCreateChatWithFriend:(OCTFriend *)friend;

/**
 * Removes given messages.
 *
 * @param messages Array with messages to remove.
 *
 * @warning Destructive operation! There is no way to restore messages after removal.
 */
- (void)removeMessages:(NSArray<OCTMessageAbstract *> *)messages withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens;

/**
 * Removes all messages in chat and chat itself.
 *
 * @param chat Chat to remove in.
 * @param removeChat Whether remove chat or not
 *
 * @warning Destructive operation! There is no way to restore chat or messages after removal.
 */
- (void)removeAllMessagesInChat:(OCTChat *)chat removeChat:(BOOL)removeChat;

/**
 * Send text message to specific chat
 *
 * @param chat Chat send message to.
 * @param text Text to send.
 * @param type Type of message to send.
 * @param userSuccessBlock Block called when message was successfully send.
 *     message Message that was send.
 * @param userFailureBlock Block called when submanager failed to send message.
 *    error Error that occurred. See OCTToxErrorFriendSendMessage for all error codes.
 */
- (void)sendMessageToChat:(OCTChat *)chat
                     text:(NSString *)text
                     type:(OCTToxMessageType)type
             successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
             failureBlock:(void (^)(NSError *error))userFailureBlock;

/**
 * Set our typing status for a chat. You are responsible for turning it on or off.
 *
 * @param isTyping Status showing whether user is typing or not.
 * @param chat Chat to set typing status.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTToxErrorSetTyping for all error codes.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)setIsTyping:(BOOL)isTyping inChat:(OCTChat *)chat error:(NSError **)error;

- (void)setMessageReaded:(OCTMessageAbstract *)message;

- (void)setMessageFileOpened:(OCTMessageAbstract *)message;

- (void)setMessageFileDuration:(NSString *)duration message:(OCTMessageAbstract *)message;

- (void)setIsMute:(BOOL)isMute inChat:(OCTChat *)chat withoutNotifying:(NSArray<RLMNotificationToken *> *)tokens;

- (void)markChatMessagesAsRead:(OCTChat *)chat;

- (void)queryFriendIsSupportOfflineMessage:(OCTFriend *)friend;

- (void)uploadPushToken:(NSString *)token;

- (void)sendOfflineFriendAcceptRequestWithPublicKey:(NSString *)publicKey;

- (void)sendGroupMessageToChat:(OCTChat *)chat
                          text:(NSString *)text
                  successBlock:(void (^)(OCTMessageAbstract *message))userSuccessBlock
                  failureBlock:(void (^)(NSError *error))userFailureBlock;

- (void)createGroupWithName:(NSString *)name
                  groupType:(NSInteger)groupType
               successBlock:(OCTGroupMessageSuccessBlock)successBlock
               failureBlock:(OCTGroupMessageFailureBlock)failureBlock;

- (void)inviteFriend:(OCTFriend *)friend toGroupChat:(OCTChat *)chat;

- (void)joinPublicGroup:(NSString *)groupShareId;

- (void)kickoutPeer:(NSString *)publicKey fromGroupChat:(OCTChat *)chat;

- (void)getPeerListWithGroupNumber:(NSInteger)groupNumber page:(NSUInteger)page;

- (BOOL)setGroupTitleWithGroupNumber:(NSInteger)groupNumber title:(NSString *)title;

- (void)getGroupTitleWithGroupNumber:(NSInteger)groupNumber;

- (void)getGroupInfoWithGroupNumber:(NSInteger)groupNumber;

- (BOOL)leaveGroupWithGroupNumber:(NSInteger)groupNumber;

- (void)setGroupRemarkWithGroupNumber:(NSInteger)groupNumber remark:(NSString *)remark;

- (void)sendStrangerCommandMessage:(NSString *)message;

- (void)sendStrangerMessage:(NSData *)messageData command:(OCTToxStrangerCmd)cmd botFriendNumber:(OCTToxFriendNumber)botFriendNumber;

@end
