//
//  OCTObjectExtension.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import CoreServices
import Chatto
import ChattoAdditions
import RxSwift
import RxCocoa

extension MessageStatus {
    static func from(textStatus: Int) -> MessageStatus {
        switch textStatus {
        case 0:
            return .sending
        case 1:
            return .success
        default:
            return .failed
        }
    }
}

extension OCTMessageFileType {
    func toMessageStatus() -> MessageStatus {
        switch self {
        case .canceled, .paused:
            return .failed
        case .waitingConfirmation:
            return .sending
        case .loading:
            return .sending
        case .ready:
            return .success
        @unknown default:
            fatalError()
        }
    }
}

extension OCTMessageAbstract {
    func toMessageModel(isGroup: Bool, fileService: FileService) -> ChatItemProtocol {
        if let messageText = messageText {
            switch messageText.messageType {
            case 0:
                let model = ChattoAdditionsMessageModel(uid: uniqueIdentifier,
                                                        senderId: senderPublicKey,
                                                        type: TextMessageModel.chatItemType,
                                                        isIncoming: !isOutgoing(),
                                                        date: Date(timeIntervalSince1970: dateInterval),
                                                        status: MessageStatus.from(textStatus: messageText.status))
                
                return TextMessageModel(messageModel: model, text: messageText.text ?? "")
            case 1:
                return TipMessageModel(uid: uniqueIdentifier, text: messageText.text ?? "")
            default:
                return SystemMessageModel(uid: uniqueIdentifier, isGroup: isGroup)
            }
        }
        
        if let messageCall = messageCall {
            let model = ChattoAdditionsMessageModel(uid: uniqueIdentifier,
                                                    senderId: senderPublicKey,
                                                    type: CallMessageModel.chatItemType,
                                                    isIncoming: !isOutgoing(),
                                                    date: Date(timeIntervalSince1970: dateInterval),
                                                    status: .success)
            
            let answered = messageCall.callEvent == .answered
            return CallMessageModel(messageModel: model, duration: messageCall.callDuration, answered: answered)
        }
        
        guard let file = messageFile else {
            return TipMessageModel(uid: uniqueIdentifier, text: "")
        }
        
        var progressHandlerModel: TransferProgressHanlder & ChatItemProtocol
        let fileSizeString = ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: ByteCountFormatter.CountStyle.file)
        if file.isImage() {
            let model = ChattoAdditionsMessageModel(uid: uniqueIdentifier,
                                                    senderId: senderPublicKey,
                                                    type: PhotoMessageModel.chatItemType,
                                                    isIncoming: !isOutgoing(),
                                                    date: Date(timeIntervalSince1970: dateInterval),
                                                    status: file.fileType.toMessageStatus())

            let image = fileService.image(withFilePath: file.filePath(), isVideo: false)
            progressHandlerModel = PhotoMessageModel(messageModel: model, image: image, imageSize: image?.size ?? .zero, fileSize: fileSizeString, filePath: file.filePath(), transferStatus: file.transferStatus(), renewable: file.isOffline)
        } else if file.isVideo() {
            let model = ChattoAdditionsMessageModel(uid: uniqueIdentifier,
                                                    senderId: senderPublicKey,
                                                    type: VideoMessageModel.chatItemType,
                                                    isIncoming: !isOutgoing(),
                                                    date: Date(timeIntervalSince1970: dateInterval),
                                                    status: file.fileType.toMessageStatus())
            let image = fileService.image(withFilePath: file.filePath(), isVideo: true)
            progressHandlerModel = VideoMessageModel(messageModel: model, image: image, imageSize: image?.size ?? .zero, fileSize: fileSizeString, filePath: file.filePath(), duration: file.duration, transferStatus: file.transferStatus(), renewable: file.isOffline)
        } else if file.isAudio() {
            let model = ChattoAdditionsMessageModel(uid: uniqueIdentifier,
                                                    senderId: senderPublicKey,
                                                    type: AudioMessageModel.chatItemType,
                                                    isIncoming: !isOutgoing(),
                                                    date: Date(timeIntervalSince1970: dateInterval),
                                                    status: file.fileType.toMessageStatus())

            progressHandlerModel = AudioMessageModel(messageModel: model, duration: file.durationFromFileName(), filePath: file.filePath(), transferStatus: file.transferStatus(), renewable: file.isOffline, unread: !file.opened)
        } else {
            let model = ChattoAdditionsMessageModel(uid: uniqueIdentifier,
                                                    senderId: senderPublicKey,
                                                    type: FileMessageModel.chatItemType,
                                                    isIncoming: !isOutgoing(),
                                                    date: Date(timeIntervalSince1970: dateInterval),
                                                    status: file.fileType.toMessageStatus())
            
            progressHandlerModel = FileMessageModel(messageModel: model, fileName: file.fileName, fileSize: fileSizeString, filePath: file.filePath(), transferStatus: file.transferStatus(), renewable: file.isOffline)
        }
        
        if file.fileType == .loading {
            let messageId = file.messageId
            let progress = isOutgoing()
                ? fileService.uploadProgress.filter { $0.0 == messageId }.map { $0.1 }
                : fileService.downloadProgress.filter { $0.0 == messageId }.map { $0.1 }
            progress.bind(to: progressHandlerModel.progress).disposed(by: progressHandlerModel.disposeBag)
        }
        return progressHandlerModel
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

extension OCTMessageFile {
    func durationFromFileName() -> UInt {
        guard let name = fileName else {
            return 0
        }
        
        var duration: UInt = 0
        let fileName = (name as NSString).deletingPathExtension
        if fileName.contains("_"), let durationString = fileName.components(separatedBy: "_").last {
            duration = UInt(durationString) ?? 0
        } else if fileName.contains(" "), let durationString = fileName.components(separatedBy: " ").first {
            duration = UInt(durationString) ?? 0
        } else {
            duration = UInt(fileName) ?? 0
        }
        return duration
    }
    
    func transferStatus() -> TransferStatus {
        if expired {
            return .expired
        }
        switch fileType {
        case .canceled, .paused:
            return isOffline ? .idle : .failed
        case .waitingConfirmation:
            return .idle
        case .loading:
            return .transfering
        case .ready:
            return .success
        @unknown default:
            fatalError()
        }
    }
}

extension OCTFriend {
    var isVerified: Bool {
        return publicKey == BotService.shared.offlineBot.publicKey
    }
}

extension OCTChat {
    var isVerified: Bool {
        if isGroup {
            return isGroup
                && self.groupType == 1
                && verifiedGroupShareIds.contains(self.groupId)
        }
        
        return (friends?.firstObject() as? OCTFriend)?.isVerified ?? false
    }
}
