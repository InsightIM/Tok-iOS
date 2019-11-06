//
//  TextMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/18.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class TextMessageViewModel: DecoratedMessageViewModelProtocol {
    let messageModel: MessageModelProtocol
    let messageViewModel: MessageViewModelProtocol
    let text: String
    
    let cellAccessibilityIdentifier = "tok.message.text.cell"
    let bubbleAccessibilityIdentifier = "tok.message.text.bubble"
    
    init(messageModel: TextMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.messageModel = messageModel
        self.messageViewModel = messageViewModel
        self.text = messageModel.text
    }
    
    open func willBeShown() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
    
    open func wasHidden() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
}
