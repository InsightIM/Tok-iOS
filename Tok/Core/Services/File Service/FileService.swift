//
//  FileService.swift
//  Tok
//
//  Created by Bryce on 2019/8/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

class FileService {
    private let disposeBag = DisposeBag()
    
    private let processQueue = DispatchQueue(label: "com.insight.messages.service.process")
    private let downloadQueue: FileQueue
    private let uploadQueue: FileQueue
    private let avatarQueue: FileQueue
    
    private let tokManager: TokManager
    private let database: Database
    let fileManager: TokFileManager
    
    let downloadProgress = BehaviorRelay<(OCTToxMessageId, Double)>(value: (0,0))
    let uploadProgress = BehaviorRelay<(OCTToxMessageId, Double)>(value: (0,0))
    
    init(tokManager: TokManager, database: Database) {
        self.tokManager = tokManager
        self.database = database
        self.fileManager = tokManager.fileManager
        self.downloadQueue = FileQueue()
        self.uploadQueue = FileQueue()
        self.avatarQueue = FileQueue(maxConcurrentOperationCount: OperationQueue.defaultMaxConcurrentOperationCount)
        
        setup()
        bindDelegate()
    }
    
    deinit {
        downloadQueue.cancelAllOperations()
        uploadQueue.cancelAllOperations()
        avatarQueue.cancelAllOperations()
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
    
    private func setup() {
        database.cancelPendingFiles()
        // TODO cleanup files folder
    }
    
    private func bindDelegate() {
        tokManager.rx.fileControlReceived()
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .subscribe(onNext: { [weak self] (control, friendNumber, fileNumber) in
                guard let self = self else { return }
                guard let op = self.find(fileNumber: fileNumber, friendNumber: friendNumber) else {
                    return
                }
                let messageAbstract = self.database.findFileMessage(by: op.messageId) // avatar does not be saved, 
                switch control {
                case .resume:
                    guard let message = messageAbstract else {
                        return
                    }
                    self.database.update(object: message, block: { theMessage in
                        let file = theMessage.messageFile
                        if file?.pausedBy != .user {
                            file?.fileType = .loading
                        } else {
                            file?.fileType = .paused
                        }
                    })
                case .pause:
                    guard let message = messageAbstract else {
                        return
                    }
                    self.database.update(object: message, block: { theMessage in
                        let file = theMessage.messageFile
                        file?.pausedBy = .friend
                        file?.fileType = .paused
                    })
                case .cancel:
                    op.cancel()
                    guard let message = messageAbstract else {
                        return
                    }
                    if message.isOutgoing() {
                        self.database.update(object: message, block: { theMessage in
                            let file = theMessage.messageFile
                            file?.fileType = .canceled
                            file?.internalFileNumber = -1
                        })
                    } else {
                        self.database.deleteMessage(by: message.uniqueIdentifier)
                    }
                @unknown default:
                    fatalError()
                }
            })
            .disposed(by: disposeBag)
        
        tokManager.rx.fileMessageReceived()
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .subscribe(onNext: { [weak self] (fileNumber, friendNumber, kind, fileSize, data) in
                guard let self = self else { return }
                switch kind {
                case .data:
                    if !self.database.isGroupBot(friendNumber: friendNumber),
                        !self.database.isFileBot(friendNumber: friendNumber),
                        !self.database.isOfflineBot(friendNumber: friendNumber) {
                        self.handleFileMessage(fileNumber: fileNumber, friendNumber: friendNumber, fileSize: fileSize, data: data)
                    } else {
                        self.handleBotFileMessage(fileNumber: fileNumber, friendNumber: friendNumber, fileSize: fileSize, data: data)
                    }
                case .avatar:
                    self.handleAvatarMessage(fileNumber: fileNumber, friendNumber: friendNumber, fileSize: fileSize)
                case .nodesFile:
                    self.handleNodesFileMessage(fileNumber: fileNumber, friendNumber: friendNumber, fileSize: fileSize)
                @unknown default: fatalError()
                }
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(Notification.Name(kOCTFriendConnectionStatusChangeNotification))
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .filterMap { notification -> FilterMap<Int> in
                guard let userInfo = notification.userInfo as? [String: NSNumber],
                    let status = userInfo["status"],
                    status.intValue != OCTToxConnectionStatus.none.rawValue,
                    let friendNumber = userInfo["friendNumber"] else {
                        return .ignore
                }
                return .map(friendNumber.intValue)
            }
            .subscribe(onNext: { [weak self] friendNumber in
                self?.sendAvatar(toFriend: OCTToxFriendNumber(friendNumber))
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(Notification.Name(kOCTUserAvatarWasUpdatedNotification))
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .subscribe(onNext: { [weak self] _ in
                guard let onlineFriends: [OCTFriend] = self?.database.onlineFriends().toList() else {
                    return
                }
                for friend in onlineFriends {
                    self?.sendAvatar(toFriend: friend.friendNumber)
                }
            })
            .disposed(by: disposeBag)
        
        tokManager.rx.fileChunkReceived()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (data, fileNumber, friendNumber, position) in
                guard let self = self else { return }
                guard let op = self.find(fileNumber: fileNumber, friendNumber: friendNumber) as? DownloadFileOperation else {
                    return
                }
                op.handleChunk(data: data, position: position)
            })
            .disposed(by: disposeBag)
        
        tokManager.rx.fileChunkRequest()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (fileNumber, friendNumber, position, length) in
                guard let self = self else { return }
                guard let op = self.find(fileNumber: fileNumber, friendNumber: friendNumber) as? UploadFileOperation else {
                    return
                }
                op.handleChunkRequest(position: position, length: length)
            })
            .disposed(by: disposeBag)
    }
    
    private func find(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber) -> BaseFileOperation? {
        if let op = self.downloadQueue.find(fileNumber: fileNumber, friendNumber: friendNumber) {
            return op
        }
        if let op = self.uploadQueue.find(fileNumber: fileNumber, friendNumber: friendNumber) {
            return op
        }
        if let op = self.avatarQueue.find(fileNumber: fileNumber, friendNumber: friendNumber) {
            return op
        }
        return nil
    }
    
    private func handleFileMessage(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, fileSize: OCTToxFileSize, data: Data?) {
        guard let data = data, let fileDisplayName = String(data: data, encoding: .utf8) else {
            return
        }
        guard let publicKey = try? self.tokManager.tox.publicKey(fromFriendNumber: friendNumber),
            let friend = self.database.findFriend(withPublicKey: publicKey),
            friend.blocked == false,
            let chat = self.database.findChat(publicKey: publicKey) else {
                return
        }
        
        let messageId = self.tokManager.tox.generateMessageId()
        let fileMessage = self.saveFileMessage(fileNumber: Int32(fileNumber), friendNumber: friendNumber, fileSize: fileSize, fileDisplayName: fileDisplayName, senderId: friend.uniqueIdentifier, senderPublicKey: friend.publicKey, chat: chat, dateInterval: 0, isOffline: false, messageId: messageId, tokMessageType: .normal)
        if let message = fileMessage {
            enqueue(messageAbstract: message, friendNumber: friendNumber)
        }
    }
    
    private func handleBotFileMessage(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, fileSize: OCTToxFileSize, data: Data?) {
        guard fileSize > 0, let pb = data, let model = try? FileTransfer(data: pb) else {
            return
        }
        guard let op = self.downloadQueue.find(by: "\(model.msgId)") as? DownloadFileOperation else {
            return
        }
        guard friendNumber == op.friendNumber else {
            return
        }
        guard let message = self.database.findFileMessage(by: OCTToxMessageId(model.msgId)),
            let messageFile = message.messageFile else {
                return
        }
        
        // update database
        let expired = model.code == 1
        self.database.update(object: messageFile, block: { file in
            file.internalFileNumber = Int32(fileNumber)
            file.fileSize = fileSize
            file.expired = expired
        })
        guard !expired else {
            op.cancel()
            return
        }
        // update filenumber
        op.fileNumber = fileNumber
        // start run
        op.run()
    }
    
    private func handleAvatarMessage(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, fileSize: OCTToxFileSize) {
        guard let friend = database.friend(with: friendNumber, tox: tokManager.tox) else {
            return
        }
        guard fileSize > 0 else {
            database.clearFriendAvatar(with: friend.publicKey)
            try? self.tokManager.tox.fileSendControl(forFileNumber: OCTToxFileNumber(friendNumber), friendNumber: friendNumber, control: .cancel)
            return
        }
        guard fileSize <= kOCTManagerMaxAvatarSize else {
            try? self.tokManager.tox.fileSendControl(forFileNumber: OCTToxFileNumber(friendNumber), friendNumber: friendNumber, control: .cancel)
            return
        }
        
        let hash = tokManager.tox.hashData(friend.avatarData)
        if let remoteHash = try? tokManager.tox.fileGetFileId(forFileNumber: fileNumber, friendNumber: friendNumber),
            hash == remoteHash {
            return
        }
        
        let messageId = tokManager.tox.generateMessageId()
        let output = FileDataOutput()
        let operaion = DownloadFileOperation(output: output,
                                             messageId: messageId,
                                             tox: tokManager.tox,
                                             database: database,
                                             kind: .avatar,
                                             friendNumber: friendNumber,
                                             fileNumber: fileNumber,
                                             fileSize: fileSize,
                                             completion: { [weak self] (operation, success) in
                                                guard let self = self else { return }
                                                guard success else { return }
                                                guard let friend = self.database.friend(with: operation.friendNumber, tox: self.tokManager.tox) else {
                                                    return
                                                }
                                                print("Update avatar: \(friend)")
                                                self.database.update(object: friend, block: { theFriend in
                                                    theFriend.avatarData = output.resultData
                                                })
        })
        avatarQueue.add(operaion)
    }
    
    private func handleNodesFileMessage(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, fileSize: OCTToxFileSize) {
        guard fileSize > 0 else {
            try? self.tokManager.tox.fileSendControl(forFileNumber: OCTToxFileNumber(friendNumber), friendNumber: friendNumber, control: .cancel)
            return
        }
        
        let localData = try? Data(contentsOf: ToxNodes.filePath())
        let hash = tokManager.tox.hashData(localData)
        if let remoteHash = try? tokManager.tox.fileGetFileId(forFileNumber: fileNumber, friendNumber: friendNumber),
            hash == remoteHash {
            return
        }
        
        let messageId = tokManager.tox.generateMessageId()
        let output = FileDataOutput()
        let operaion = DownloadFileOperation(output: output,
                                             messageId: messageId,
                                             tox: tokManager.tox,
                                             database: database,
                                             kind: .avatar,
                                             friendNumber: friendNumber,
                                             fileNumber: fileNumber,
                                             fileSize: fileSize,
                                             completion: { (operation, success) in
                                                guard success else { return }
                                                print("Update Remote nodes")
                                                ToxNodes.store(data: output.resultData)
        })
        avatarQueue.add(operaion)
    }
    
    func saveFileMessage(fileNumber: Int32, friendNumber: OCTToxFriendNumber, fileSize: OCTToxFileSize, fileDisplayName: String, senderId: String?, senderPublicKey: String?, chat: OCTChat, dateInterval: TimeInterval, isOffline: Bool, messageId: OCTToxMessageId, tokMessageType: TokMessageType) -> OCTMessageAbstract? {
        guard fileSize > 0 || tokMessageType == .tempGroupMessage else {
            try? self.tokManager.tox.fileSendControl(forFileNumber: OCTToxFileNumber(friendNumber), friendNumber: friendNumber, control: .cancel)
            return nil
        }
        // save to database
        let messageAbstract = database.buildFileMessage(fileNumber: fileNumber, fileType: .waitingConfirmation, fileSize: OCTToxFileSize(fileSize), fileName: fileDisplayName, filePath: nil, fileUTI: fileDisplayName.fileUTI(), chat: chat, senderId: senderId, senderPublicKey: senderPublicKey, dateInterval: dateInterval, isOffline: isOffline, messageId: messageId, opened: false, tokMessageType: tokMessageType)
        
        return messageAbstract
    }
    
    func enqueue(messageAbstract: OCTMessageAbstract, friendNumber: OCTToxFriendNumber) {
        guard UserDefaultsManager().autodownloadFiles else {
            return
        }
        guard let messageFile = messageAbstract.messageFile else {
            fatalError("messageFile is nil")
        }
        guard let fileDisplayName = messageFile.fileName else {
            fatalError("fileName is nil")
        }
        
        let messageId = messageFile.messageId
        let fileNumber = messageFile.internalFileNumber
        let fileSize = messageFile.fileSize
        
        let pathExtension = (fileDisplayName as NSString).pathExtension
        let fileName = (UUID().uuidString as NSString).appendingPathExtension(pathExtension)
        let resultPath = self.fileManager.url(atChatDirectory: .files, fileName: fileName)
        let output = FilePathOutput(tempFilePath: self.fileManager.tempPath(pathExtension: pathExtension), resultFilePath: resultPath)
        self.addDownload(output: output, messageId: messageId, friendNumber: friendNumber, fileNumber: OCTToxFileNumber(fileNumber), fileSize: fileSize)
        database.update(object: messageAbstract, block: { theMessageAbstract in
            theMessageAbstract.messageFile?.fileType = .loading
            theMessageAbstract.messageFile?.internalSetFilePath(resultPath.path)
        })
    }
    
    func resumeFileMessage(id: String) {
        processQueue.async {
            guard let message = self.database.findMessage(by: id),
                let messageFile = message.messageFile,
                let fileDisplayName = messageFile.fileName,
                let chat = self.database.findChat(byId: message.chatUniqueIdentifier) else {
                    return
            }
            
            let botFriendNumber = chat.isGroup
                ? try? self.database.friendNumber(publicKey: BotService.shared.fileBot.publicKey, tox: self.tokManager.tox)
                : try? self.database.friendNumber(publicKey: BotService.shared.offlineBot.publicKey, tox: self.tokManager.tox)
            
            guard let friendNumber = botFriendNumber else {
                return
            }
            
            let pathExtension = (fileDisplayName as NSString).pathExtension
            let fileName = (UUID().uuidString as NSString).appendingPathExtension(pathExtension)
            let messageId = messageFile.messageId
            // enqueue
            let resultPath = self.fileManager.url(atChatDirectory: .files, fileName: fileName)
            let output = FilePathOutput(tempFilePath: self.fileManager.tempPath(pathExtension: pathExtension), resultFilePath: resultPath)
            
            self.addDownload(output: output, messageId: messageId, friendNumber: friendNumber, fileNumber: UInt32.max, fileSize: messageFile.fileSize)
            
            self.database.update(object: messageFile, block: { file in
                file.fileType = .loading
                file.internalSetFilePath(resultPath.path)
            })
        }
    }
    
    func cancel(id: String, isIncoming: Bool) {
        guard let message = database.findMessage(by: id),
            let messageFile = message.messageFile else {
                return
        }
        if isIncoming {
            cancelDownload(messageId: messageFile.messageId)
        } else {
            cancelUpload(messageId: messageFile.messageId)
        }
        database.update(object: messageFile) { file in
            file.fileType = .canceled
        }
    }
    
    private func addDownload(output: FileOutputProtocol, messageId: OCTToxMessageId, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber, fileSize: OCTToxFileSize) {
//        performAsynchronouslyOnMainThread {
            let operaion = DownloadFileOperation(output: output, messageId: messageId, tox: self.tokManager.tox, database: self.database, kind: .data, friendNumber: friendNumber, fileNumber: OCTToxFileNumber(fileNumber), fileSize: fileSize, progress: { [weak self] (op, progress) in
                self?.downloadProgress.accept((op.messageId, progress))
                }, completion: { [weak self] (op, success) in
                    guard let self = self else { return }
                    guard success else { return }
                    guard let message = self.database.findFileMessage(by: op.messageId) else { return }
                    self.processVideoIfNeeded(message: message)
            })
            self.downloadQueue.add(operaion)
//        }
    }
    
    private func cancelDownload(messageId: OCTToxMessageId) {
//        performAsynchronouslyOnMainThread {
            let operation = self.downloadQueue.find(by: DownloadFileOperation.operationId(messageId: messageId))
            operation?.cancel()
//        }
    }
    
    func addUpload(input: FileInputProtocol, messageId: OCTToxMessageId, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber, fileSize: OCTToxFileSize) {
//        performAsynchronouslyOnMainThread {
            let operation = UploadFileOperation(input: input, messageId: messageId, tox: self.tokManager.tox, database: self.database, kind: .data, friendNumber: friendNumber, fileNumber: UInt32.max, fileSize: fileSize, progress: { [weak self] (op, progress) in
                self?.uploadProgress.accept((op.messageId, progress))
            })
            self.uploadQueue.add(operation)
//        }
    }
    
    func cancelUpload(messageId: OCTToxMessageId) {
//        performAsynchronouslyOnMainThread {
            let operation = self.uploadQueue.find(by: UploadFileOperation.operationId(messageId: messageId))
            operation?.cancel()
//        }
    }
}

extension FileService {
    func processVideoIfNeeded(message: OCTMessageAbstract) {
        guard let messageFile = message.messageFile,
            let filePath = messageFile.filePath(),
            messageFile.isVideo() else {
                return
        }
        let path = URL(fileURLWithPath: filePath)
        let fileName = path.deletingPathExtension().lastPathComponent + ".jpg"
        let thumbnailUrl = self.fileManager.url(atChatDirectory: .thumbs, fileName: fileName)
        
        let (duration, thumbnail) = self.createThumbnailOfVideo(url: path, saveTo: thumbnailUrl)
        thumbnail?.saveToFile(path: thumbnailUrl)
        self.database.update(object: messageFile, block: { file in
            file.fileType = .ready
            file.duration = duration
        })
    }
    
    func image(withFilePath path: String?, isVideo: Bool) -> UIImage? {
        guard let path = path else {
            return nil
        }
        if !isVideo {
            return YYImage(contentsOfFile: path)
        }
        let url = URL(fileURLWithPath: path)
        let fileName = url.deletingPathExtension().lastPathComponent + ".jpg"
        let thumbnailUrl = self.fileManager.url(atChatDirectory: .thumbs, fileName: fileName)
        return YYImage(contentsOfFile: thumbnailUrl.path)
    }
}

private extension FileService {
    func sendAvatar(toFriend friendNumber: OCTToxFriendNumber) {
        if let avatar = database.settingsStorage()?.userAvatarData {
            let fileSize = OCTToxFileSize(avatar.count)
            let hash = tokManager.tox.hashData(avatar)
            
            var error: NSError?
            let fileNumber = tokManager.tox.fileSend(withFriendNumber: friendNumber, kind: .avatar, fileSize: fileSize, fileId: hash, fileName: nil, error: &error)
            guard fileNumber != kOCTToxFileNumberFailure else {
                return
            }
            
            let messageId = tokManager.tox.generateMessageId()
            let input = FileDataInput(data: avatar)
            let operation = UploadFileOperation(input: input, messageId: messageId, tox: tokManager.tox, database: database, kind: .avatar, friendNumber: friendNumber, fileNumber: fileNumber, fileSize: fileSize)
            avatarQueue.add(operation)
        } else {
            tokManager.tox.fileSend(withFriendNumber: friendNumber, kind: .avatar, fileSize: 0, fileId: nil, fileName: nil, error: nil)
        }
    }
}

private extension FileService {
    func createThumbnailOfVideo(url: URL, saveTo: URL) -> (String?, UIImage?) {
        let asset = AVAsset(url: url)
        let mediaDurationFormatter: DateComponentsFormatter = {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.zeroFormattingBehavior = [.pad]
            formatter.unitsStyle = .positional
            return formatter
        }()
        
        let sec = max(CMTimeGetSeconds(asset.duration), 1)
        let duration = mediaDurationFormatter.string(from: sec)
        
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        //Can set this to improve performance if target size is known before hand
        //assetImgGenerate.maximumSize = CGSize(width,height)
        let time = CMTimeMakeWithSeconds(0.0, preferredTimescale: 1)
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: img)
            
            try thumbnail.jpegData(compressionQuality: 0.75)?.write(to: saveTo)
            
            return (duration, thumbnail)
        } catch {
            print(error.localizedDescription)
            return (duration, nil)
        }
    }
}
