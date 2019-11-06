//
//  Chat.swift
//  Tok
//
//  Created by Bryce on 2019/10/16.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

struct Chat {
    let friendPublicKey: String?
    let lastActivityDateInterval: TimeInterval
    let isMute: Bool
    
    let isGroup: Bool
    let groupNumber: Int64
    let shareId: String?
    let title: String?
    let groupDescription: String?
    let groupMemebersCount: Int
    let groupType: Int
    let ownerPublicKey: String?
    let groupStatus: Int
    
    init(_ dbChat: OCTChat) {
        friendPublicKey = (dbChat.friends?.firstObject() as? OCTFriend)?.publicKey
        lastActivityDateInterval = dbChat.lastActivityDateInterval
        isMute = dbChat.isMute
        isGroup = dbChat.isGroup
        groupNumber = Int64(dbChat.groupNumber)
        shareId = dbChat.groupId
        title = dbChat.title
        groupDescription = dbChat.groupDescription
        groupMemebersCount = dbChat.groupMemebersCount
        groupType = dbChat.groupType
        ownerPublicKey = dbChat.ownerPublicKey
        groupStatus = dbChat.groupStatus
    }
    
    init(groupNumber: Int64,
         lastActivityDateInterval: TimeInterval = Date().timeIntervalSince1970,
         isMute: Bool = true,
         isGroup: Bool = true,
         friendPublicKey: String? = nil,
         shareId: String? = nil,
         title: String? = nil,
         groupDescription: String? = nil,
         groupMemebersCount: Int = 0,
         groupType: Int = 0,
         ownerPublicKey: String? = nil,
         groupStatus: Int = 0) {
        self.groupNumber = groupNumber
        self.lastActivityDateInterval = Date().timeIntervalSince1970
        self.isMute = isMute
        self.isGroup = isGroup
        
        self.friendPublicKey = friendPublicKey
        self.shareId = shareId
        self.title = title
        self.groupDescription = groupDescription
        self.groupMemebersCount = groupMemebersCount
        self.groupType = groupType
        self.ownerPublicKey = ownerPublicKey
        self.groupStatus = groupStatus
    }
}
