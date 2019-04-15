//
//  OCTPeer.h
//  Tok
//
//  Created by Bryce on 2018/9/27.
//  Copyright © 2018 Insight. All rights reserved.
//

#import "OCTObject.h"
@class OCTFriend;

NS_ASSUME_NONNULL_BEGIN

@interface OCTPeer : OCTObject

@property NSInteger groupNumber;

@property (nullable) NSString *nickname;

/**
 * Public key of a friend, is kOCTToxPublicKeyLength length.
 * Is constant, cannot be changed.
 */
@property (nullable) NSString *publicKey;

@property (nullable) NSData *avatarData;

+ (instancetype)createFromFriend:(OCTFriend *)friend;

@end

RLM_ARRAY_TYPE(OCTPeer)

NS_ASSUME_NONNULL_END
