//
//  MessagesSender.swift
//  Tok
//
//  Created by Bryce on 2019/8/8.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

class MessagesSender {
    enum SendError: Error, LocalizedError {
        case cantReadFile
        case cantMoveFile
        case notConnected
        case fileTooBig
        case timeout
        case cantSend
        
        var errorDescription: String? {
            switch self {
            case .cantReadFile: return "Cannot read file."
            case .cantMoveFile: return "Cannot save send file to uploads folder."
            case .notConnected: return "Friend is not connected at the moment."
            case .fileTooBig: return NSLocalizedString("Only offline files smaller than 10M are supported", comment: "")
            case .timeout: return "Timeout"
            case .cantSend: return "Cannot send message to a friend"
            }
        }
    }
    
    private let disposeBag = DisposeBag()
    private let processQueue = DispatchQueue(label: "com.insight.messages.sender.process")
    let database: Database
    let tokManager: TokManager
    let fileManager: TokFileManager
    private let fileService: FileService
    private let avatarQueue: OperationQueue
    
    private struct Constants {
        static let maxTextLength = Int(kOCTToxMaxMessageLength / 4)
    }
    
    private var taskQueue: [String: SerialTaskQueue] // [ChatId: Queue]
    
    init(tokManager: TokManager, database: Database, fileService: FileService) {
        self.tokManager = tokManager
        self.database = database
        self.fileManager = tokManager.fileManager
        self.fileService = fileService
        self.avatarQueue = OperationQueue()
        self.avatarQueue.qualityOfService = .background
        
        self.taskQueue = [:]
        enqueueSendingMessages()
    }
    
    // MARK: - Send Text Message
    
    func add(text: String, to chatId: String) {
        processQueue.async {
            guard let chat = self.database.findChat(byId: chatId) else {
                return
            }
            let tox = self.tokManager.tox
            
            for subText in text.split(by: Constants.maxTextLength) {
                // 1. db
                let messageId = tox.generateMessageId()
                self.database.buildTextMessage(text: subText, chat: chat, senderId: nil, senderPublicKey: nil, status: 0, type: .normal, messageType: 0, messageId: messageId, dateInterval: 0)
                
                // 2. enqueue
                let chatId = chat.uniqueIdentifier!
                let task = self.buildSendTask(text: subText, chatId: chatId, messageId: messageId)
                var queue = self.taskQueue[chatId]
                if queue == nil {
                    queue = SerialTaskQueue()
                    self.taskQueue[chatId] = queue
                }
                queue?.addTask(task)
            }
        }
    }
    
    // MARK: - Private
    
    private func enqueueSendingMessages() {
        DispatchQueue.global(qos: .background).async {
            self.database.setTimeoutMessagesToFailure()
            performAsynchronouslyOnMainThread {
                let sendingMessages = self.database.findAllSendingMessages()
                sendingMessages
                    .compactMap { message -> (String, OCTToxMessageId, String)? in
                        if let messageText = message.messageText {
                            guard let text = messageText.text else {
                                return nil
                            }
                            return (message.chatUniqueIdentifier, messageText.messageId, text)
                        }
                        
                        return nil
                    }
                    .group(by: { $0.0 })
                    .forEach { (key, value) in
                        let queue = SerialTaskQueue()
                        value.forEach { (chatId, messageId, text) in
                            let task = self.buildSendTask(text: text, chatId: chatId, messageId: messageId)
                            queue.addTask(task)
                        }
                        self.taskQueue[key] = queue
                }
            }
        }
    }
    
    private func buildSendTask(text: String, chatId: String, messageId: OCTToxMessageId) -> Observable<Void> {
        // 2. send
        let task = send(text, to: chatId, messageId: messageId, database: database, tox: tokManager.tox)
            .subscribeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .debug("Send text: \(text)")
            .asObservable()
            .timeout(.seconds(15), scheduler: MainScheduler.instance)
            .retry(.customTimerDelayed(maxCount: 50, delayCalculator: {
                #if DEBUG
                print("Retry \(text) times: \($0)")
                #endif
                return $0 == 1 ? .seconds(32) : .seconds(5) // first retry delay 32s, otherwise 5s
            })) // 2.1 retry 5 mins
            .do(onNext: { [unowned self] messageId in
                self.database.updateTextMessage(id: messageId, status: 1)
                }, onError: { [unowned self] _ in
                    self.database.updateTextMessage(id: messageId, status: 2)
            })
            .map { _ in () }
        
        return task
    }
    
    private func send(_ text: String, to chatId: String, messageId: OCTToxMessageId, database: Database, tox: OCTTox) -> Maybe<OCTToxMessageId> {
        return Maybe.create { maybe in
            guard let chat = database.findChat(byId: chatId),
                database.isExist(textMessage: messageId) else {
                    maybe(.error(SendError.cantSend))
                    return Disposables.create()
            }
            
            var error: NSError?
            let ret: OCTToxMessageId
            let realFriendNumber: OCTToxFriendNumber
            if chat.isGroup {
                guard let bot = database.findFriend(withPublicKey: BotService.shared.groupBot.publicKey), bot.isConnected else {
                    maybe(.error(SendError.notConnected))
                    return Disposables.create()
                }
                
                let model = GroupMessageReq()
                model.groupId = UInt64(chat.groupNumber)
                model.frPk = tox.publicKey.data(using: .utf8)
                model.msg = text.data(using: .utf8)
                model.localMsgId = UInt64(messageId);
                ret = tox.sendGroupMessage(withBotFriendNumber: bot.friendNumber, groupCmd: .message, messageId: messageId, message: model.data(), error: &error)
                
                realFriendNumber = bot.friendNumber
            } else {
                guard let friend = chat.friends?.firstObject() as? OCTFriend else {
                    maybe(.error(SendError.cantSend))
                    return Disposables.create()
                }
                
                let friendNumber = friend.friendNumber
                if friend.isConnected {
                    let data = text.data(using: .utf8)
                    ret = tox.sendMessage(withFriendNumber: friendNumber, type: .normal, messageId: messageId, message: data, error: &error)
                    
                    realFriendNumber = friendNumber
                } else {
                    guard let bot = database.findFriend(withPublicKey: BotService.shared.offlineBot.publicKey), bot.isConnected else {
                        maybe(.error(SendError.notConnected))
                        return Disposables.create()
                    }
                    
                    let model = OfflineMessageReq()
                    model.cryptoMessage = tox.encryptOfflineMessage(friendNumber, message: text)
                    model.localMsgId = messageId
                    model.toPk = friend.publicKey.data(using: .utf8)
                    
                    ret = tox.sendOfflineMessage(withBotFriendNumber: bot.friendNumber, offlineCmd: .send, messageId: messageId, message: model.data(), error: &error)
                    
                    realFriendNumber = bot.friendNumber
                }
            }
            
            guard ret > 0, error == nil else {
                maybe(.error(SendError.cantSend))
                return Disposables.create()
            }
            
            let friendOffline = NotificationCenter.default.rx.notification(Notification.Name(kOCTFriendConnectionStatusChangeNotification))
                .filterMap { notification -> FilterMap<Int> in
                    guard let userInfo = notification.userInfo as? [String: NSNumber],
                        let friendNumber = userInfo["friendNumber"],
                        let status = userInfo["status"],
                        friendNumber.intValue == realFriendNumber else {
                            return .ignore
                    }
                    return .map(status.intValue)
                }
                .debug("Send Text Message friend offline")
                .subscribe(onNext: { status in
                    let error = status == OCTToxConnectionStatus.none.rawValue ? SendError.notConnected: SendError.timeout
                    maybe(.error(error))
                })
            
            let messageDelived = Observable.just((), scheduler: MainScheduler.instance)
                .flatMap { [unowned self] in
                    self.tokManager.rx.messageDelived()
                }
                .filterMap { arg -> FilterMap<OCTToxMessageId> in
                    let (msgId, friendNumber) = arg
                    guard msgId == messageId, friendNumber == realFriendNumber else {
                        return .ignore
                    }
                    return .map(msgId)
                }
                .subscribe(onNext: { msgId in
                    maybe(.success(msgId))
                    maybe(.completed)
                }, onError: { error in
                    maybe(.error(error))
                })
            
            return Disposables.create {
                messageDelived.dispose()
                friendOffline.dispose()
            }
        }
    }
}

// MARK: - Send File

extension MessagesSender {
    func sendFile(data: Data, fileName: String = UUID().uuidString, to chat: OCTChat, needMove: Bool, failure: ((SendError) -> Void)?) {
        let path = fileManager.url(atChatDirectory: .files, fileName: fileName)
        do {
            try data.write(to: path)
            sendFile(url: path, fileName: fileName, to: chat, needMove: needMove, failure: failure)
        } catch {
            failure?(SendError.cantMoveFile)
        }
    }
    
    func sendFile(url: URL, fileName: String, to chat: OCTChat, needMove: Bool, failure: ((SendError) -> Void)?) {
        var filePath = url.path
        
        let messageId = tokManager.tox.generateMessageId()
        let errorBlock: (SendError, UInt64, String, OCTChat) -> Void = { [unowned self] (error, fileSize, filePath, chat) in
            let message = self.database.buildFileMessage(fileNumber: Int32.max, fileType: .canceled, fileSize: OCTToxFileSize(fileSize), fileName: fileName, filePath: filePath, fileUTI: fileName.fileUTI(), chat: chat, senderId: nil, senderPublicKey: nil, dateInterval: 0, isOffline: false, messageId: messageId, opened: true)
            self.database.add(object: message)
            failure?(error)
        }
        
        if needMove {
            let uniqueName = (UUID().uuidString as NSString).appendingPathExtension(url.pathExtension)
            let toPath = fileManager.url(atChatDirectory: .files, fileName: uniqueName).path
            do {
                try FileManager.default.copyItem(atPath: filePath, toPath: toPath)
                filePath = toPath
            } catch {
                errorBlock(SendError.cantMoveFile, 0, filePath, chat)
                return
            }
        }
        
        guard let (sendToBot, friendNumber, fileSize) = processFile(filePath: filePath, chat: chat, errorBlock: errorBlock) else {
            return
        }
        
        let message = database.buildFileMessage(fileNumber: Int32.max, fileType: .loading, fileSize: OCTToxFileSize(fileSize), fileName: fileName, filePath: filePath, fileUTI: fileName.fileUTI(), chat: chat, senderId: nil, senderPublicKey: nil, dateInterval: 0, isOffline: sendToBot, messageId: messageId, opened: true)
        database.add(object: message)
        // create thumbnail and get duration
        fileService.processVideoIfNeeded(message: message)
        
        let input = FilePathInput(filePath: filePath)
        fileService.addUpload(input: input, messageId: messageId, friendNumber: friendNumber, fileNumber: UInt32.max, fileSize: OCTToxFileSize(fileSize))
    }
    
    private func processFile(filePath: String, chat: OCTChat, errorBlock: ((SendError, UInt64, String, OCTChat) -> Void)?) -> (Bool, OCTToxFriendNumber, UInt64)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
            let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
                errorBlock?(SendError.cantReadFile, 0, filePath, chat)
                return nil
        }
        
        var friendNumber: OCTToxFriendNumber
        var sendToBot = false
        if chat.isGroup {
            guard let bot = database.findFriend(withPublicKey: BotService.shared.groupBot.publicKey), bot.isConnected else {
                errorBlock?(SendError.notConnected, fileSize, filePath, chat)
                return nil
            }
            friendNumber = bot.friendNumber
            sendToBot = true
        } else {
            guard let friend = chat.friends?.firstObject() as? OCTFriend else {
                errorBlock?(SendError.notConnected, fileSize, filePath, chat)
                return nil
            }
            if friend.isConnected {
                friendNumber = friend.friendNumber
            } else if let bot = database.findFriend(withPublicKey: BotService.shared.offlineBot.publicKey), bot.isConnected {
                friendNumber = bot.friendNumber
                sendToBot = true
            } else {
                errorBlock?(SendError.notConnected, fileSize, filePath, chat)
                return nil
            }
        }
        
        if sendToBot, fileSize > kOCTManagerMaxOfflineFileSize {
            errorBlock?(SendError.fileTooBig, fileSize, filePath, chat)
            return nil
        }
        
        return (sendToBot, friendNumber, fileSize)
    }
}

// MARK: - Other Public Methods

extension MessagesSender {
    func resend(id: String, faliure: ((SendError) -> Void)?) {
        guard let message = database.findMessage(by: id),
            let chat = database.findChat(byId: message.chatUniqueIdentifier) else {
                return
        }
        
        if let messageText = message.messageText {
            guard let text = messageText.text else { return }
            database.deleteMessage(by: id)
            add(text: text, to: chat.uniqueIdentifier)
        } else if let messageFile = message.messageFile, let filePath = messageFile.filePath() {
            guard let chat = database.findChat(byId: message.chatUniqueIdentifier) else {
                return
            }
            let results = processFile(filePath: filePath, chat: chat) { (error, _, _, _) in
                faliure?(error)
            }
            
            guard let (sendToBot, friendNumber, fileSize) = results else {
                return
            }

            database.update(object: messageFile) { file in
                file.isOffline = sendToBot
                file.fileType = .loading
            }
            
            let messageId = messageFile.messageId
            let input = FilePathInput(filePath: filePath)
            fileService.addUpload(input: input, messageId: messageId, friendNumber: friendNumber, fileNumber: UInt32.max, fileSize: OCTToxFileSize(fileSize))
        }
    }
    
    func forward(id: String, to chat: OCTChat, faliure: ((String) -> Void)?) {
        guard let message = database.findMessage(by: id) else {
            return
        }
        
        if let messageText = message.messageText {
            guard let text = messageText.text else { return }
            add(text: text, to: chat.uniqueIdentifier)
        }
        
        if let messageFile = message.messageFile, let filePath = messageFile.filePath() {
            let url = URL(fileURLWithPath: filePath)
            let pathExtension = url.pathExtension
            let fileName = (UUID().uuidString as NSString).appendingPathExtension(pathExtension)!
            
            sendFile(url: url, fileName: fileName, to: chat, needMove: true) { error in
                
            }
        }
    }
}
