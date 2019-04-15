//
//  ForwardMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/1/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class ForwardMessageViewModel {
    let message: MessageModel
    
    init(message: MessageModel) {
        self.message = message
    }
    
    func sendMessage(to chat: OCTChat) {
        switch message.kind {
        case .text(let text):
            UserService.shared.toxMananger!.chats.sendMessage(to: chat, text: text, type: .normal, successBlock: nil, failureBlock: nil)
        case .photo(let model), .video(let model):
            guard let item = model as? MediaModel, let path = item.messageFile.filePath() else {
                return
            }
            
            UserService.shared.toxMananger!.files.sendFile(atPath: path, moveToUploads: false, to: chat, failureBlock: nil)
        case .audio(let item):
            guard let path = item.path else {
                return
            }
            UserService.shared.toxMananger!.files.sendFile(atPath: path, moveToUploads: false, to: chat, failureBlock: nil)
        case .file(let item):
            guard let path = item.path else {
                return
            }
            UserService.shared.toxMananger!.files.sendFile(atPath: path, moveToUploads: false, to: chat, failureBlock: nil)
        case .attributedText, .location, .emoji, .system, .custom:
            break
        }
    }
}
