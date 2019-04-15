//
//  MessageModel.swift
//  Tok
//
//  Created by Bryce on 2018/9/10.
//  Copyright © 2018年 Insight. All rights reserved.
//

import RxSwift
import RxCocoa
import AVFoundation
import MobileCoreServices

enum FileTransferProgress: Equatable {
    case waiting, loading(Double), failed, success
    
    static func == (lhs: FileTransferProgress, rhs: FileTransferProgress) -> Bool {
        switch (lhs, rhs) {
        case (.waiting, .waiting):
            return true
        case let (.loading(lp), .loading(rp)):
            return lp == rp
        case (.failed, .failed):
            return true
        case (.success, .success):
            return true
        default:
            return false
        }
    }
}

protocol FileStatusType {
    var status: BehaviorRelay<FileTransferProgress> { get }
    var progressObject: ChatProgressBridge { get }
    
    var progress: BehaviorRelay<Float> { get }
}

extension OCTMessageFileType {
    func toFileStatus() -> FileTransferProgress {
        switch self {
        case .canceled, .paused:
            return .failed
        case .waitingConfirmation:
            return .waiting
        case .loading:
            return .loading(0)
        case .ready:
            return .success
        }
    }
}

enum MessageStatus: Int {
    case sending = 0
    case sent
    case failed
    case unread
    case waiting
    
    var imageName: String {
        switch self {
        case .sending:
            return "StatusSending"
        case .sent:
            return "StatusSent"
        case .failed:
            return "StatusFailed"
        case .unread:
            return "UnreadDot"
        case .waiting:
            return ""
        }
    }
}

struct CallMessageItem {
    var messageCall: OCTMessageCall
    
    var duration: TimeInterval {
        return messageCall.callDuration
    }
    
    var answered: Bool {
        return messageCall.callEvent == .answered
    }
}

struct MessageModel: MessageType, Equatable, Comparable {
    
    var messageId: String
    var sender: Sender
    var sentDate: Date
    var kind: MessageKind
    
    var status: MessageStatus {
        var messageStatus: MessageStatus = .waiting
        guard message.isInvalidated == false else {
            return .waiting
        }
        
        if let messageText = message.messageText {
            messageStatus = MessageStatus(rawValue: messageText.status) ?? .waiting
            
            if message.isOutgoing() == false, messageStatus != .failed {
                return .waiting
            }
        } else if let messageFile = message.messageFile {
            switch messageFile.fileType.toFileStatus() {
            case .failed: messageStatus = .failed
            case .success:
                if messageFile.isAudio(), message.isOutgoing() == false {
                    messageStatus = messageFile.opened ? .waiting : .unread
                } else {
                    messageStatus = .sent
                }
            case .loading: messageStatus = .sending
            case .waiting: messageStatus = .waiting
            }
        }
        
        return messageStatus
    }
    
    var message: OCTMessageAbstract {
        didSet {
            updateStatus()
        }
    }
    
    var isOutgoing: Bool {
        return message.isOutgoing()
    }
    
    private func updateStatus() {
        let updateBlock: (MessageModel, FileStatusType) -> Void = { messageModel, fileItem in
            guard let messageFile = messageModel.message.messageFile else {
                return
            }
            
            let submanagerFiles = UserService.shared.toxMananger!.files
            switch messageFile.fileType {
            case .waitingConfirmation:
                break
//                if messageModel.message.isOutgoing() == false, UserDefaultsManager().autodownloadFiles {
//                    submanagerFiles.acceptFileTransfer(messageModel.message)
//                }
            case .loading:
                _ = try? submanagerFiles.add(fileItem.progressObject, forFileTransfer: messageModel.message)
            case .paused, .canceled, .ready:
                break
            }
            
            fileItem.status.accept(messageFile.fileType.toFileStatus())
        }
        
        switch kind {
        case .photo(var item):
            if let filePath = message.messageFile?.filePath() {
                item.image = UIImage(contentsOfFile: filePath)
            }
            guard let item = item as? FileStatusType else {
                return
            }
            updateBlock(self, item)
        case .video(let item):
            guard let item = item as? MediaModel else {
                return
            }
            item.fetchThumbnailAndDuration { (_, duration) in
                UserService.shared.toxMananger!.chats.setMessageFileDuration(duration, message: self.message)
            }
            updateBlock(self, item)
        case .audio(let item):
            guard let item = item as? FileStatusType else {
                return
            }
            updateBlock(self, item)
        case .file(let item):
            guard let item = item as? FileStatusType else {
                return
            }
            updateBlock(self, item)
        default:
            return
        }
    }
    
    private init(message: OCTMessageAbstract, kind: MessageKind, sender: Sender, messageId: String, date: Date) {
        self.message = message
        self.kind = kind
        self.sender = sender
        self.messageId = messageId
        self.sentDate = date
        
        updateStatus()
    }
    
    init(model: OCTMessageAbstract, sender: Sender, fileStorage: OCTFileStorageProtocol) {
        var kind: MessageKind = .text("")
        if let messageText = model.messageText {
            kind = .text(messageText.text ?? "")
        } else if let file = model.messageFile {
            if file.isImage() {
                let media = MediaModel(messageFile: file, isOutgoing: model.isOutgoing(), thumbPath: fileStorage.pathForVideoThumbFilesDirectory)
                kind = .photo(media)
            } else if file.isVideo() {
                let media = MediaModel(messageFile: file, isOutgoing: model.isOutgoing(), thumbPath: fileStorage.pathForVideoThumbFilesDirectory)
                media.fetchThumbnailAndDuration { (_, duration) in
                    UserService.shared.toxMananger!.chats.setMessageFileDuration(duration, message: model)
                }
                kind = .video(media)
            } else if file.isAudio() {
                let item = AudioMessageModel(messageFile: file)
                kind = .audio(item)
            } else {
                let item = FileMessageModel(messageFile: file)
                kind = .file(item)
            }
        } else if let messageCall = model.messageCall {
            let callItem = CallMessageItem(messageCall: messageCall)
            kind = .custom(callItem)
        } else {
            kind = .system(NSLocalizedString("Messages to this chat and calls are now secured with peer-to-peer communication, end-to-end encryption.\nTap for more info >", comment: ""))
        }
        self.init(message: model, kind: kind, sender: sender, messageId: model.uniqueIdentifier, date: model.date())
    }
    
    static func == (lhs: MessageModel, rhs: MessageModel) -> Bool {
        return lhs.messageId == rhs.messageId
    }
    
    static func < (lhs: MessageModel, rhs: MessageModel) -> Bool {
        return lhs.message.dateInterval < rhs.message.dateInterval
    }
}

extension OCTMessageFile {
    func isImage() -> Bool {
        guard let uti = self.fileUTI else {
            return false
        }
        
        if UTTypeEqual(uti as CFString, kUTTypeGIF) {
            return true
        }
        else if UTTypeEqual(uti as CFString, kUTTypeJPEG) {
            return true
        }
        else if UTTypeEqual(uti as CFString, kUTTypePNG) {
            return true
        }
        return false
    }
    
    func isAudio() -> Bool {
        if (self.fileName as NSString?)?.pathExtension.lowercased() == audioExtension {
            return true
        }
        return false
    }
    
    func isVideo() -> Bool {
        guard let uti = self.fileUTI else {
            return false
        }
        if UTTypeEqual(uti as CFString, kUTTypeMPEG) {
            return true
        }
        else if UTTypeEqual(uti as CFString, kUTTypeMPEG4) {
            return true
        }
        else if UTTypeEqual(uti as CFString, kUTTypeAVIMovie) {
            return true
        }
        else if UTTypeEqual(uti as CFString, kUTTypeQuickTimeMovie) {
            return true
        }
        else if UTTypeEqual(uti as CFString, kUTTypeVideo) {
            return true
        }
        return false
    }
    
    func imageNameFromType() -> String? {
        if isAudio() {
            return "MessageAudio"
        } else if isImage() {
            return "MessagePhoto"
        }
        else if isVideo() {
            return "MessageVideo"
        }
        
        guard let fileExtension = (fileName as NSString?)?.pathExtension else {
            return "MessageFile"
        }
        
        switch fileExtension {
        case "avi", "flv", "mov":
            return "MessageVideo"
        case "wav", "wma", "aac":
            return "MessageAudio"
        default:
            return "MessageFile"
        }
    }
    
}
