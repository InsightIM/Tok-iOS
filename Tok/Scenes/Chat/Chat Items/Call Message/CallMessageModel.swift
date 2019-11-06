//
//  CallMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions

class CallMessageModel: DecoratedMessageModelProtocol {

    static var chatItemType: ChatItemType {
        return "call"
    }
    
    let messageModel: MessageModelProtocol
    
    let duration: TimeInterval
    let answered: Bool
    
    init(messageModel: ChattoAdditionsMessageModel, duration: TimeInterval, answered: Bool) {
        self.messageModel = messageModel
        self.duration = duration
        self.answered = answered
    }
}
