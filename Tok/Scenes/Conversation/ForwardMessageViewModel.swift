//
//  ForwardMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/1/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class ForwardMessageViewModel {
    let message: MessageModel?
    let text: String?
    let messageSender: MessageSender
    let toxManager: OCTManager
    init(message: MessageModel, toxManager: OCTManager, messageSender: MessageSender) {
        self.message = message
        self.text = nil
        self.toxManager = toxManager
        self.messageSender = messageSender
    }
    
    init(text: String, toxManager: OCTManager, messageSender: MessageSender) {
        self.message = nil
        self.text = text
        self.toxManager = toxManager
        self.messageSender = messageSender
    }
    
    func sendMessage(to chat: OCTChat) {
        if let text = text {
            messageSender.add(text: text, to: chat)
        } else if let message = message {
            switch message.kind {
            case .text(let text):
                messageSender.add(text: text, to: chat)
            case .photo(let model), .video(let model):
                guard let item = model as? MediaModel, let path = item.messageFile.filePath() else {
                    return
                }
                
                let pathExtension = (path as NSString).pathExtension
                let fileName = (UUID().uuidString as NSString).appendingPathExtension(pathExtension)!
                toxManager.files.sendFile(atPath: path, fileName: fileName, moveToUploads: false, to: chat, failureBlock: nil)
            case .audio(let item):
                guard let path = item.path else {
                    return
                }
                
                let pathExtension = (path as NSString).pathExtension
                let fileName = (UUID().uuidString as NSString).appendingPathExtension(pathExtension)!
                toxManager.files.sendFile(atPath: path, fileName: fileName, moveToUploads: false, to: chat, failureBlock: nil)
            case .file(let item):
                guard let path = item.path else {
                    return
                }
                
                let fileName = (path as NSString).lastPathComponent
                toxManager.files.sendFile(atPath: path, fileName: fileName, moveToUploads: false, to: chat, failureBlock: nil)
            case .attributedText, .location, .emoji, .system, .custom, .tip:
                break
            }
        }
    }
}
