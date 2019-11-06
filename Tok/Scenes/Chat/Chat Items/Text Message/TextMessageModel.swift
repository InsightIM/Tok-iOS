//
//  TextMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/18.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import ChattoAdditions

class TextMessageModel: DecoratedMessageModelProtocol {
    let messageModel: MessageModelProtocol
    let text: String
    var status: ChattoAdditionsMessageStatus
    init(messageModel: ChattoAdditionsMessageModel, text: String) {
        self.messageModel = messageModel
        self.text = text
        self.status = messageModel.status
    }
}
