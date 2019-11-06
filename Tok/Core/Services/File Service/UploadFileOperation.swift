//
//  UploadFileOperation.swift
//  Tok
//
//  Created by Bryce on 2019/8/8.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxSwiftExt

protocol FileInputProtocol {
    func prepareToRead() -> Bool
    func bytesWithPosition(position: OCTToxFileSize, length: UInt) -> Data?
}

class UploadFileOperation: BaseFileOperation {
    private let disposeBag = DisposeBag()
    
    let input: FileInputProtocol
    init(input: FileInputProtocol, messageId: OCTToxMessageId, tox: OCTTox, database: Database, kind: OCTToxFileKind, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber, fileSize: OCTToxFileSize, progress: ((BaseFileOperation, Double) -> Void)? = nil, completion: ((BaseFileOperation, Bool) -> Void)? = nil) {
        self.input = input
        super.init(messageId: messageId, tox: tox, database: database, kind: kind, friendNumber: friendNumber, fileNumber: fileNumber, fileSize: fileSize, progress: progress, completionCallback: completion)
    }
    
    override func getOperationId() -> String {
        return BaseFileOperation.operationId(messageId: messageId)
    }
    
    override func execute() -> Bool {
        guard input.prepareToRead() else {
            return false
        }
        
        if kind == .avatar {
            return true
        }
        
        guard let message = database.findFileMessage(by: messageId),
            let messageFile = message.messageFile,
            let chat = database.findChat(byId: message.chatUniqueIdentifier) else {
                return false
        }
        
        var data: Data?
        if messageFile.isOffline {
            let transfer = FileTransfer()
            transfer.msgId = UInt64(messageId)
            transfer.realName = messageFile.fileName?.data(using: .utf8)
            if chat.isGroup {
                transfer.groupId = UInt64(chat.groupNumber)
            } else {
                guard let friend = chat.friends?.firstObject() as? OCTFriend else {
                    return false
                }
                transfer.toPk = friend.publicKey.data(using: .utf8)
            }
            
            data = transfer.data()
        } else {
            data = messageFile.fileName?.data(using: .utf8)
        }
        
        var error: NSError?
        let fileNumber = tox.fileSend(withFriendNumber: friendNumber, kind: .data, fileSize: fileSize, fileId: nil, fileName: data, error: &error)
        guard fileNumber != kOCTToxFileNumberFailure, error == nil else {
            return false
        }
        
        self.fileNumber = fileNumber
        database.update(object: messageFile, block: { file in
            file.internalFileNumber = Int32(fileNumber)
        })
        
        return true
    }
    
    func handleChunkRequest(position: OCTToxFileSize, length: UInt) {
        guard self.isExecuting else {
            completion(success: false)
            return
        }
        
        if length == 0 {
            completion(success: true)
            return
        }
        
        let readData = self.input.bytesWithPosition(position: position, length: length)
        guard let data = readData else {
            completion(success: false)
            return
        }
        
        var result = false
        var sendqError = false
        repeat {
            do {
                try self.tox.fileSendChunk(forFileNumber: fileNumber, friendNumber: friendNumber, position: position, data: data)
                result = true
            } catch {
                result = false
                let errorCode = (error as NSError).code
                sendqError = errorCode == OCTToxErrorFileSendChunk.sendq.rawValue
                if sendqError {
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
        } while (!result && sendqError)
        
        guard result else {
            completion(success: false)
            return
        }
        
        self.update(bytesDone: position + Int64(length))
    }
}
