//
//  Friend.swift
//  Tok
//
//  Created by Bryce on 2019/7/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

struct Friend {
    enum State: Int {
        case normal = 0 //0 appected, 1 sent friend request but not be appected
        case waiting = 1
    }
    
    let nickname: String
    let friendNumber: OCTToxFriendNumber
    let publicKey: String
    let statusMessage: String?
    let connectionStatus: OCTToxConnectionStatus
    let friendState: State
    
    init(friend: OCTFriend) {
        nickname = friend.nickname
        friendNumber = friend.friendNumber
        publicKey = friend.publicKey
        statusMessage = friend.statusMessage
        connectionStatus = friend.connectionStatus
        friendState = State(rawValue: friend.friendState) ?? .normal
    }
}
