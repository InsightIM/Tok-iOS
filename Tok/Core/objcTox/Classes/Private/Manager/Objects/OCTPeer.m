//
//  OCTPeer.m
//  Tok
//
//  Created by Bryce on 2018/9/27.
//  Copyright © 2018 Insight. All rights reserved.
//

#import "OCTPeer.h"
#import "OCTFriend.h"

@implementation OCTPeer

+ (instancetype)createFromFriend:(OCTFriend *)friend
{
    OCTPeer *peer = [OCTPeer new];
    peer.avatarData = friend.avatarData;
    peer.nickname = friend.nickname;
    peer.publicKey = friend.publicKey;
    
    return peer;
}

@end
