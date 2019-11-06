
//
//  MessageViewModelDefaultBuilder.swift
//  Tok
//
//  Created by Bryce on 2019/6/19.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class MessageViewModelDefaultBuilder {
    
    let avatarManager: AvatarManager
    let nameManager: NameManager
    
    let messageService: MessageService
    public init(messageService: MessageService) {
        self.messageService = messageService
        self.avatarManager = AvatarManager.shared
        self.nameManager = messageService.nameManager
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    public func createMessageViewModel(_ message: MessageModelProtocol) -> MessageViewModelProtocol {
        // Override to use default avatarImage
        return MessageViewModel(dateFormatter: MessageViewModelDefaultBuilder.dateFormatter,
                                messageModel: message,
                                avatarImage: avatarManager.image(bySenderId: message.senderId, messageService: messageService),
                                decorationAttributes: BaseMessageDecorationAttributes(),
                                topLabelText: nameManager.name(by: message.senderId))
    }
}
