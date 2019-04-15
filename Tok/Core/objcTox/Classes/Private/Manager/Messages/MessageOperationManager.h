//
//  MessageOperationManager.h
//  Tok
//
//  Created by Bryce on 2019/3/22.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@class OCTTox;
@class OCTChat;
@class OCTFriend;
@class OCTRealmManager;

NS_ASSUME_NONNULL_BEGIN

@interface MessageOperationManager : NSObject

- (instancetype)initWithTox:(OCTTox *)tox
               realmManager:(OCTRealmManager *)realmManager;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)sendText:(NSString *)text toFriendNumber:(OCTToxFriendNumber)friendNumber inChat:(OCTChat *)chat messageType:(OCTToxMessageType)messageType;

- (void)sendResponseMessage:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber message:(NSString *)message time:(NSTimeInterval)time;

- (void)sendConfirmMessage:(OCTToxMessageId)messageId friendNumber:(OCTToxFriendNumber)friendNumber success:(BOOL)success;

- (void)sendAssistMessageWithFriendNumber:(OCTToxFriendNumber)friendNumber;

- (void)resendUndeliveredMessagesToFriend:(OCTFriend *)friend;

- (void)setSendingMessageToFailed;

@end

NS_ASSUME_NONNULL_END
