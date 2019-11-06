//
//  ForwardMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/1/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class ForwardMessageViewModel {
    let messageId: String?
    let text: String?
    
    let messageService: MessageService
    let messageSender: MessagesSender
    init(messageId: String, messageService: MessageService) {
        self.messageId = messageId
        self.messageService = messageService
        
        self.text = nil
        self.messageSender = messageService.messageSender
    }
    
    init(text: String, messageService: MessageService) {
        self.messageId = nil
        self.messageService = messageService
        
        self.text = text
        self.messageSender = messageService.messageSender
    }
    
    func sendMessage(to chat: OCTChat) {
        if let messageId = messageId {
            messageSender.forward(id: messageId, to: chat, faliure: nil)
        } else if let text = text {
            messageSender.add(text: text, to: chat.uniqueIdentifier)
        }
    }
}
