//
//  SystemMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/6/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions

class SystemMessageModel: ChatItemProtocol {
    let uid: String
    let type: String = SystemMessageModel.chatItemType
    let text: String
    let isGroup: Bool
    static var chatItemType: ChatItemType {
        return "SystemMessageModel"
    }
    
    init(uid: String, isGroup: Bool) {
        self.uid = uid
        let text = isGroup
            ? NSLocalizedString("· Here can have up to 100,000 members\n· Chat anonymous\n· Please follow the group rules", comment: "")
            : NSLocalizedString("Messages to this chat and calls are now secured with peer-to-peer communication, end-to-end encryption.\nTap for more info >", comment: "")
        self.text = text
        self.isGroup = isGroup
    }
}
