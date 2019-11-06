//
//  TipMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/6/19.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto

class TipMessageModel: ChatItemProtocol {
    let uid: String
    let type: String = TipMessageModel.chatItemType
    let text: String
    
    static var chatItemType: ChatItemType {
        return "TipMessageModel"
    }
    
    init(uid: String, text: String) {
        self.uid = uid
        self.text = text
    }
}
