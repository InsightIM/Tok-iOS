//
//  DownloadFileOperation.swift
//  Tok
//
//  Created by Bryce on 2019/7/30.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxSwiftExt

protocol FileOutputProtocol {
    func prepareToWrite() -> Bool
    func write(data: Data) -> Bool
    func finishWriting() -> Bool
    func cancel()
}

class DownloadFileOperation: BaseFileOperation {
    private let disposeBag = DisposeBag()
    
    let output: FileOutputProtocol
    init(output: FileOutputProtocol, messageId: OCTToxMessageId, tox: OCTTox, database: Database, kind: OCTToxFileKind, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber, fileSize: OCTToxFileSize, progress: ((BaseFileOperation, Double) -> Void)? = nil, completion: ((BaseFileOperation, Bool) -> Void)? = nil) {
        self.output = output
        super.init(messageId: messageId, tox: tox, database: database, kind: kind, friendNumber: friendNumber, fileNumber: fileNumber, fileSize: fileSize, progress: progress, completionCallback: completion)
    }
    
    override func getOperationId() -> String {
        return BaseFileOperation.operationId(messageId: messageId)
    }
    
    override func execute() -> Bool {
        if kind == .avatar {
            run()
            return true
        }
        
        guard let message = database.findFileMessage(by: messageId),
            let messageFile = message.messageFile,
            let chat = database.findChat(byId: message.chatUniqueIdentifier) else {
                return false
        }
        
        guard messageFile.isOffline else {
            run()
            return true
        }
        
        var result: Bool
        if chat.isGroup {
            result = sendPullGroupFileMessage(msgId: messageFile.messageId, groupNumber: chat.groupNumber)
        } else {
            result = sendPullOfflineFileMessage(msgId: messageFile.messageId)
        }
        
        return result
    }
    
    func run() {
        guard output.prepareToWrite() else {
            completion(success: false)
            return
        }
        
        do {
            try tox.fileSendControl(forFileNumber: fileNumber, friendNumber: friendNumber, control: .resume)
        } catch {
            completion(success: false)
        }
    }
    
    func handleChunk(data: Data?, position: OCTToxFileSize) {
        guard let chunk = data else {
            if self.fileSize == self.bytesDone, self.output.finishWriting() {
                completion(success: true)
            } else {
                completion(success: false)
            }
            
            return
        }
        
        guard self.bytesDone == position else {
            completion(success: false)
            return
        }
        
        guard self.output.write(data: chunk) else {
            completion(success: false)
            return
        }
        
        self.update(bytesDone: self.bytesDone + Int64(chunk.count))
    }
    
    private func sendPullGroupFileMessage(msgId: OCTToxMessageId, groupNumber: Int) -> Bool {
        let model = GroupFilePullReq()
        model.msgId = UInt64(msgId)
        model.groupId = UInt64(groupNumber)
        
        var error: NSError?
        tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: OCTToxGroupCmd.filePull, messageId: msgId, message: model.data(), error: &error)
        return error == nil
    }
    
    private func sendPullOfflineFileMessage(msgId: OCTToxMessageId) -> Bool {
        let model = OfflineFilePullReq()
        model.msgId = UInt64(msgId)
        
        guard let botFriendNumber = getBotFriendNumber() else {
            return false
        }
        var error: NSError?
        tox.sendOfflineMessage(withBotFriendNumber: botFriendNumber, offlineCmd: OCTToxMessageOfflineCmd.filePull, messageId: msgId, message: model.data(), error: &error)
        return error == nil
    }
    
    private func getBotFriendNumber() -> OCTToxFriendNumber? {
        var error: NSError?
        let publicKey = BotService.shared.offlineBot.publicKey
        let botFriendNumber = tox.friendNumber(withPublicKey: publicKey, error: &error)
        guard error == nil else {
            return nil
        }
        return botFriendNumber
    }
}
