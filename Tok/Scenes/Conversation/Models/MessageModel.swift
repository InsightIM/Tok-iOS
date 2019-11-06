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
import DeepDiff

extension MessageModel: DiffAware {
    typealias DiffId = String
    
    var diffId: String {
        return messageId
    }
    
    static func compareContent(_ a: MessageModel, _ b: MessageModel) -> Bool {
        guard a.messageId == b.messageId, a.status == b.status else {
            return false
        }
        switch (a.kind, b.kind) {
        case (.photo(let l), .photo(let r)):
            guard let l = l as? MediaModel, let r = r as? MediaModel else {
                return false
            }
            guard l.status.value == r.status.value else {
                return false
            }
            if case .loading = r.status.value {
                return l.progressObject == r.progressObject
            }
            return true
        case (.video(let l), .video(let r)):
            guard let l = l as? MediaModel, let r = r as? MediaModel else {
                return false
            }
            guard l.status.value == r.status.value else {
                return false
            }
            if case .loading = r.status.value {
                return l.progressObject == r.progressObject
            }
            return true
        case (.audio(let l), .audio(let r)):
            guard let l = l as? AudioMessageModel, let r = r as? AudioMessageModel else {
                return false
            }
            guard l.status.value == r.status.value else {
                return false
            }
            if case .loading = r.status.value {
                return l.progressObject == r.progressObject
            }
            return true
        case (.file(let l), .file(let r)):
            guard let l = l as? FileMessageModel, let r = r as? FileMessageModel else {
                return false
            }
            guard l.status.value == r.status.value else {
                return false
            }
            if case .loading = r.status.value {
                return l.progressObject == r.progressObject
            }
            return true
        case (.tip(let l), .tip(let r)):
            return l == r
        case (.text(let l), .text(let r)):
            return l == r
        case (.system(let l), .system(let r)):
            return l == r
        case (.custom(let l), .custom(let r)):
            guard let _ = l as? CallMessageItem, let _ = r as? CallMessageItem else {
                return false
            }
            return true
        default:
            return false
        }
        
    }
}

enum FileTransferProgress: Equatable {
    case waiting, loading(Double), failed, success, expired
    
    static func == (lhs: FileTransferProgress, rhs: FileTransferProgress) -> Bool {
        switch (lhs, rhs) {
        case (.waiting, .waiting):
            return true
        case (.loading, .loading):
            return true
        case (.failed, .failed):
            return true
        case (.success, .success):
            return true
        case (.expired, .expired):
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
    func toFileStatus(isOffline: Bool, expired: Bool) -> FileTransferProgress {
        if expired {
            return .expired
        }
        switch self {
        case .canceled, .paused:
            return isOffline ? .waiting : .failed
        case .waitingConfirmation:
            return .waiting
        case .loading:
            return .loading(0)
        case .ready:
            return .success
        @unknown default:
            fatalError()
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
    
    var status: MessageStatus = .waiting
    
    var message: OCTMessageAbstract {
        didSet {
            updateStatus()
            updateFileStatus()
        }
    }
    
    var isOutgoing: Bool {
        return message.isOutgoing()
    }
    
    private mutating func updateStatus() {
        let currentStatus: (OCTMessageAbstract) -> MessageStatus = { message -> MessageStatus in
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
                let transferStatus = messageFile.fileType.toFileStatus(isOffline: messageFile.isOffline, expired: messageFile.expired)
                switch transferStatus {
                case .failed: messageStatus = .failed
                case .success:
                    if messageFile.isAudio(), message.isOutgoing() == false {
                        messageStatus = messageFile.opened ? .waiting : .unread
                    } else {
                        messageStatus = .sent
                    }
                case .loading: messageStatus = .sending
                case .waiting: messageStatus = .waiting
                case .expired: messageStatus = .failed
                }
            }
            
            return messageStatus
        }
        
        self.status = currentStatus(self.message)
    }
    
    private func updateFileStatus() {
        let updateBlock: (MessageModel, FileStatusType) -> Void = { messageModel, fileItem in
            guard let messageFile = messageModel.message.messageFile else {
                return
            }
            
            let submanagerFiles = UserService.shared.toxMananger!.files
            switch messageFile.fileType {
            case .waitingConfirmation:
                break
            case .loading:
                _ = try? submanagerFiles.add(fileItem.progressObject, forFileTransfer: messageModel.message)
            case .paused, .canceled, .ready:
                break
            @unknown default:
                fatalError()
            }
            
            fileItem.status.accept(messageFile.fileType.toFileStatus(isOffline: messageFile.isOffline, expired: messageFile.expired))
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
        updateFileStatus()
    }
    
    init(model: OCTMessageAbstract, sender: Sender, fileStorage: OCTFileStorageProtocol) {
        var kind: MessageKind = .text("")
        if let messageText = model.messageText {
            if messageText.messageType == 0 {
                kind = .text(messageText.text ?? "")
            } else if messageText.messageType == 1 {
                kind = .system(messageText.text ?? "")
            } else if messageText.messageType == 2 {
                kind = .tip(messageText.text ?? "")
            }
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
            kind = .tip(NSLocalizedString("Messages to this chat and calls are now secured with peer-to-peer communication, end-to-end encryption.", comment: ""))
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
