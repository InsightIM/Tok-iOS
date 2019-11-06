//
//  Database.swift
//  Tok
//
//  Created by Bryce on 2019/7/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import Realm
import SwiftDate

class Database {
    private let realmManager: OCTRealmManager
    
    init(realmManager: OCTRealmManager) {
        self.realmManager = realmManager
    }
    
    func add<T: RLMObject>(object: T, withoutNotifying token: RLMNotificationToken? = nil) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            db.beginWriteTransaction()
            db.add(object)
            if let token = token {
                try? db.commitWriteTransactionWithoutNotifying([token])
            } else {
                try? db.commitWriteTransaction()
            }
        }
    }
    
    func add<T: RLMObject>(objects: [T]) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            db.beginWriteTransaction()
            db.addObjects(objects as NSFastEnumeration)
            try? db.commitWriteTransaction()
        }
    }
    
    func update<T: OCTObject>(object: T, block: @escaping (T) -> Void) {
        let key = object.uniqueIdentifier
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            
            guard let object = T.object(in: db, forPrimaryKey: key) else {
                return
            }
            db.beginWriteTransaction()
            block(object)
            try? db.commitWriteTransaction()
        }
    }
    
    // MARK: - User
    
    func settingsStorage() -> OCTSettingsStorageObject? {
        return OCTSettingsStorageObject.object(in: realmManager.database(), forPrimaryKey: "kSettingsStorageObjectPrimaryKey")
    }
    
    // MARK: - Chat
    
    func findChat(byId id: String) -> OCTChat? {
        return OCTChat.object(in: realmManager.database(), forPrimaryKey: id)
    }
    
    func findChat(publicKey: String) -> OCTChat? {
        guard let db = realmManager.database() else {
            return nil
        }
        guard let friend = findFriend(withPublicKey: publicKey) else {
            return nil
        }
        let predicate = NSPredicate(format: "ANY friends == %@", friend)
        return OCTChat.objects(in: db, with: predicate).firstObject() as? OCTChat
    }
    
    @discardableResult
    func findOrCreateChat(publicKey: String) -> OCTChat? {
        guard let db = realmManager.database() else {
            return nil
        }
        guard let friend = findFriend(withPublicKey: publicKey) else {
            return nil
        }
        
        let predicate = NSPredicate(format: "ANY friends == %@", friend)
        if let chat = OCTChat.objects(in: db, with: predicate).firstObject() as? OCTChat {
            return chat
        }
        
        let chat = OCTChat()
        chat.lastActivityDateInterval = Date().timeIntervalSince1970
        
        db.beginWriteTransaction()
        db.add(chat)
        chat.friends?.add(friend)
        addDefaultTipMessage(chat: chat, in: db)
        try? db.commitWriteTransaction()
        
        return chat
    }
    
    @discardableResult
    func findOrCreateChat(friend: OCTFriend) -> OCTChat {
        let db = realmManager.database()!
        
        let predicate = NSPredicate(format: "ANY friends == %@", friend)
        if let chat = OCTChat.objects(in: db, with: predicate).firstObject() as? OCTChat {
            return chat
        }
        
        let chat = OCTChat()
        chat.lastActivityDateInterval = Date().timeIntervalSince1970
        
        db.beginWriteTransaction()
        db.add(chat)
        chat.friends?.add(friend)
        addDefaultTipMessage(chat: chat, in: db)
        try? db.commitWriteTransaction()
        
        return chat
    }
    
    func findGroupChat(by groupId: UInt64, db: RLMRealm? = nil) -> OCTChat? {
        guard groupId > 0 else {
            return nil
        }
        guard let db = db ?? realmManager.database() else {
            return nil
        }
        
        let predicate = NSPredicate(format: "groupNumber == %lld", groupId)
        let chat = OCTChat.objects(in: db, with: predicate).firstObject() as? OCTChat
        return chat
    }
    
    func findOrCreateGroupChat(by groupId: UInt64) -> OCTChat? {
        guard groupId > 0 else {
            return nil
        }
        
        if let chat = findGroupChat(by: groupId) {
            return chat
        }

        let chat = OCTChat()
        chat.lastActivityDateInterval = Date().timeIntervalSince1970
        chat.isGroup = true
        chat.groupNumber = Int(groupId)
        chat.isMute = true
        chat.groupType = 1
        autoreleasepool {
            let db = self.realmManager.database()
            db?.beginWriteTransaction()
            db?.add(chat)
            self.addDefaultTipMessage(chat: chat, in: db)
            try? db?.commitWriteTransaction()
        }

        return chat
    }
    
    func removeAllMessages(inChat chatId: String, removeChat: Bool) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            let messages = OCTMessageAbstract.objects(in: db, with: NSPredicate(format: "chatUniqueIdentifier == %@", chatId)) as! RLMResults<OCTMessageAbstract>
            guard messages.count > 0 else { return }
            db.beginWriteTransaction()
            for i in 0..<messages.count {
                let message = messages[i]
                if let messageText = message.messageText {
                    db.delete(messageText)
                }
                if let messageFile = message.messageFile {
                    db.delete(messageFile)
                }
                if let messageCall = message.messageCall {
                    db.delete(messageCall)
                }
            }
            db.deleteObjects(messages)
            
            if removeChat, let chat = OCTChat.object(in: db, forPrimaryKey: chatId) {
                db.delete(chat)
                // delete ranges
                let ranges = OCTRange.objects(in: db, with: NSPredicate(format: "chatUniqueIdentifier == %@", chatId))
                db.deleteObjects(ranges)
            }
            try? db.commitWriteTransaction()
        }
    }
    
    // MARK: - Range & Messages
    
    func findMessagesCount(chatId: String, range: OCTRange, dateInterval: TimeInterval, up: Bool) -> UInt {
        guard range.isInvalidated == false else { return 0 }
        let start = up ? range.endTimeInterval : dateInterval
        let end = up ? dateInterval : range.startTimeInterval
        
        let subPredicate = up
            ? NSPredicate(format: "dateInterval >= %lf AND dateInterval < %lf", start, end)
            : NSPredicate(format: "dateInterval > %lf AND dateInterval <= %lf", start, end)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "chatUniqueIdentifier == %@", chatId),
            NSPredicate(format: "messageText.messageType != %ld", 2),
            NSPredicate(format: "tokMessageType == %ld", TokMessageType.normal.rawValue),
            subPredicate
            ])
        let messages = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate).sortedResults(usingKeyPath: "dateInterval", ascending: false)
        return messages.count
    }
    
    func findLatestRange(chatId: String) -> OCTRange? {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@", chatId)
        return OCTRange.objects(in: realmManager.database(), with: predicate)
            .sortedResults(usingKeyPath: "endTimeInterval", ascending: false)
            .firstObject() as? OCTRange
    }
    
    func findChatLatestMessage(chatId: String) -> OCTMessageAbstract? {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "chatUniqueIdentifier == %@ AND senderUniqueIdentifier != nil", chatId),
            NSPredicate(format: "messageText != nil || messageFile != nil"),
            NSPredicate(format: "tokMessageType == %ld", TokMessageType.normal.rawValue),
            ])
        return OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
            .sortedResults(usingKeyPath: "dateInterval", ascending: false)
            .firstObject() as? OCTMessageAbstract
    }
    
    func findRanges(chatId: String, startTimeInterval: TimeInterval?, endTimeInterval: TimeInterval?) -> Results<OCTRange> {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@ AND startTimeInterval >= %lf AND endTimeInterval <= %lf", chatId, startTimeInterval ?? 0, endTimeInterval ?? Date().timeIntervalSince1970)
        return Results(results: OCTRange.objects(in: realmManager.database(), with: predicate)) 
    }
    
    func findUpClosestRange(chatId: String, startTimeInterval: TimeInterval?) -> OCTRange? {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@ AND startTimeInterval <= %lf", chatId, startTimeInterval ?? 0)
        return OCTRange.objects(in: realmManager.database(), with: predicate)
            .sortedResults(usingKeyPath: "endTimeInterval", ascending: false)
            .firstObject() as? OCTRange
    }
    
    func findDownClosestRange(chatId: String, endTimeInterval: TimeInterval?) -> OCTRange? {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@ AND endTimeInterval > %lf", chatId, endTimeInterval ?? Date().timeIntervalSince1970)
        return OCTRange.objects(in: realmManager.database(), with: predicate)
            .sortedResults(usingKeyPath: "startTimeInterval", ascending: true)
            .firstObject() as? OCTRange
    }
    
    func findCoveredRange(chatId: String, startId: UInt64, endId: UInt64) -> OCTRange? {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@ AND startMessageId >= %lld AND endMessageId <= %lld", chatId, startId, endId)
        return OCTRange.objects(in: realmManager.database(), with: predicate)
            .firstObject() as? OCTRange
    }
    
    func findUpRange(chatId: String, maxMsgId: UInt64, nextMsgId: UInt64) -> OCTRange? {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "chatUniqueIdentifier == %@", chatId),
            NSPredicate(format: "endMessageId == %lld OR endMessageId == %lld", maxMsgId, nextMsgId)
            ])
        return OCTRange.objects(in: realmManager.database(), with: predicate)
            .firstObject() as? OCTRange
    }
    
    func findDownRange(chatId: String, minPreId: UInt64) -> OCTRange? {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@ AND startMessageId == %lld", chatId, minPreId)
        return OCTRange.objects(in: realmManager.database(), with: predicate)
            .firstObject() as? OCTRange
    }
    
    func findRange(endMessageId: Int64) -> OCTRange? {
        return OCTRange.objects(in: realmManager.database(), with: NSPredicate(format: "endMessageId == %lld", endMessageId))
            .firstObject() as? OCTRange
    }
    
    func findRange(startMessageId: Int64, endMessageId: Int64) -> OCTRange? {
        guard let db = realmManager.database() else {
            return nil
        }
        return OCTRange.objects(in: db, with: NSPredicate(format: "startMessageId == %lld AND endMessageId == %lld", startMessageId, endMessageId))
            .firstObject() as? OCTRange
    }
    
    func deleteRange(rangeId: String) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            guard let range = OCTRange.object(in: db, forPrimaryKey: rangeId) else {
                return
            }
            db.beginWriteTransaction()
            db.delete(range)
            try? db.commitWriteTransaction()
        }
    }
    
    func deleteRange(startMessageId: Int64, endMessageId: Int64) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            guard let ranges = OCTRange.objects(in: db, with: NSPredicate(format: "startMessageId == %lld AND endMessageId == %lld", startMessageId, endMessageId)) as? RLMResults<OCTRange> else {
                return
            }
            db.beginWriteTransaction()
            db.deleteObjects(ranges)
            try? db.commitWriteTransaction()
        }
    }
    
    func cleanUnusedRanges() {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            let chats: [OCTChat] = self.normalChats().toList()
            let ids = chats.map { $0.uniqueIdentifier }
            let unusedRanges = OCTRange.objects(in: db, with: NSPredicate(format: "NOT (chatUniqueIdentifier IN %@)", ids))
            db.beginWriteTransaction()
            db.deleteObjects(unusedRanges)
            try? db.commitWriteTransaction()
        }
    }
    
    // MARK: - Friend
    
    // 0 accepted, 1 sent friend request but not be appected
    enum FriendState: Int {
        case accepted = 0
        case waiting = 1
    }
    
    func findFriends(predicate: NSPredicate) -> Results<OCTFriend> {
        let friends = OCTFriend.objects(in: realmManager.database(), with: predicate)
        return Results<OCTFriend>(results: friends)
    }
    
    func findFriend(withPublicKey publicKey: String) -> OCTFriend? {
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        return OCTFriend.objects(in: realmManager.database(), with: predicate).firstObject() as? OCTFriend
    }
    
    func findFriend(withPublicKey publicKey: String, friendState: FriendState) -> OCTFriend? {
        let predicate = NSPredicate(format: "publicKey == %@ AND friendState == %ld", publicKey, friendState.rawValue)
        return OCTFriend.objects(in: realmManager.database(), with: predicate).firstObject() as? OCTFriend
    }
    
    func onlineFriends() -> Results<OCTFriend> {
        let predicate = NSPredicate(format: "connectionStatus != %d", OCTToxConnectionStatus.none.rawValue)
        return Results<OCTFriend>(results: OCTFriend.objects(in: realmManager.database(), with: predicate))
    }
    
    func findPeer(withPublicKey publicKey: String) -> OCTPeer? {
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        return OCTPeer.objects(in: realmManager.database(), with: predicate).firstObject() as? OCTPeer
    }
    
    func findFriendRequest(withPublicKey publicKey: String) -> OCTFriendRequest? {
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        return OCTFriendRequest.objects(in: realmManager.database(), with: predicate).firstObject() as? OCTFriendRequest
    }
    
    func findFriendRequest(predicate: NSPredicate) -> Results<OCTFriendRequest> {
        return Results(results: OCTFriendRequest.objects(in: realmManager.database(), with: predicate))
    }
    
    func addFriendRequest(message: String?, publicKey: String, isOutgoing: Bool) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            let predicate = NSPredicate(format: "publicKey == %@", publicKey)
            guard OCTFriendRequest.objects(in: db, with: predicate).count > 0 else {
                return
            }
            guard OCTFriend.objects(in: db, with: predicate).count > 0 else {
                return
            }
            
            let request = OCTFriendRequest()
            request.publicKey = publicKey
            request.message = message
            request.dateInterval = Date().timeIntervalSince1970
            request.isOutgoing = isOutgoing
            
            db.beginWriteTransaction()
            db.add(request)
            try? db.commitWriteTransaction()
        }
    }
    
    func friendAcceptRequest(publicKey: String) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            let predicate = NSPredicate(format: "publicKey == %@", publicKey)
            guard let friend = OCTFriend.objects(in: db, with: predicate).firstObject() as? OCTFriend else {
                return
            }
            
            let friendRequest = OCTFriendRequest.objects(in: db, with: predicate).firstObject() as? OCTFriendRequest
            if friend.friendState != FriendState.accepted.rawValue {
                db.beginWriteTransaction()
                friend.friendState = FriendState.accepted.rawValue
                if let request = friendRequest {
                    db.delete(request)
                }
                try? db.commitWriteTransaction()
            }
        }
    }
    
    // MARK: - Message
    
    func findMessages(predicate: NSPredicate) -> Results<OCTMessageAbstract> {
        let messageAbstracts = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
        return Results(results: messageAbstracts)
    }
    
    func messages(of chat: OCTChat) -> Results<OCTMessageAbstract> {
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@ AND tokMessageType == %ld", chat.uniqueIdentifier, TokMessageType.normal.rawValue)
        let messageAbstracts = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate).sortedResults(usingKeyPath: "dateInterval", ascending: true)
        return Results(results: messageAbstracts)
    }
    
    func findMessage(by id: String) -> OCTMessageAbstract? {
        return OCTMessageAbstract.object(in: realmManager.database(), forPrimaryKey: id)
    }
    
    func findTextMessage(by msgId: OCTToxMessageId, tokMessageType: TokMessageType) -> OCTMessageAbstract? {
        let predicate = NSPredicate(format: "messageText.messageId == %lld AND tokMessageType == %ld", msgId, tokMessageType.rawValue)
        let objects = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
        return objects.firstObject() as? OCTMessageAbstract
    }
    
    func findFileMessage(by msgId: OCTToxMessageId, tokMessageType: TokMessageType = .normal) -> OCTMessageAbstract? {
        let predicate = NSPredicate(format: "messageFile.messageId == %lld AND tokMessageType == %ld", msgId, tokMessageType.rawValue)
        let objects = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
        return objects.firstObject() as? OCTMessageAbstract
    }
    
    func isExist(textMessage msgId: OCTToxMessageId) -> Bool {
        let predicate = NSPredicate(format: "messageText.messageId == %lld AND tokMessageType == %ld", msgId, TokMessageType.normal.rawValue)
        let objects = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
        return objects.count > 0
    }
    
    func isExist(fileMessage msgId: OCTToxMessageId) -> Bool {
        let predicate = NSPredicate(format: "messageFile.messageId == %lld AND tokMessageType == %ld", msgId, TokMessageType.normal.rawValue)
        let objects = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
        return objects.count > 0
    }
    
    func updateTextMessage(id: OCTToxMessageId, status: Int) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            let predicate = NSPredicate(format: "messageText.messageId == %lld", id)
            let messageAbstract = OCTMessageAbstract.objects(in: db, with: predicate).firstObject()
            guard let message = messageAbstract as? OCTMessageAbstract else {
                return
            }
            
            db.beginWriteTransaction()
            message.messageText?.status = status
            try? db.commitWriteTransaction()
        }
    }
    
    func buildTextMessage(text: String, chat: OCTChat, senderId: String?, senderPublicKey: String?, status: Int, type: OCTToxMessageType, messageType: Int, messageId: OCTToxMessageId, dateInterval: TimeInterval, tokMessageType: TokMessageType = .normal) {
        
        let messageText = OCTMessageText()
        messageText.text = text
        messageText.status = status
        messageText.type = type
        messageText.messageId = messageId
        messageText.messageType = messageType
        
        createMessageAbstract(chat: chat, senderId: senderId, senderPublicKey: senderPublicKey, messageText: messageText, messageFile: nil, messageCall: nil, tokMessageType: tokMessageType, dateInterval: dateInterval)
    }
    
    @discardableResult
    func buildFileMessage(fileNumber: Int32, fileType: OCTMessageFileType, fileSize: OCTToxFileSize, fileName: String?, filePath: String?, fileUTI: String?, chat: OCTChat, senderId: String?, senderPublicKey: String?, dateInterval: TimeInterval, isOffline: Bool, messageId: OCTToxMessageId, opened: Bool, tokMessageType: TokMessageType = .normal) -> OCTMessageAbstract {

        let messageFile = OCTMessageFile()
        messageFile.internalFileNumber = fileNumber
        messageFile.fileType = fileType
        messageFile.fileSize = fileSize
        messageFile.fileName = fileName
        messageFile.internalSetFilePath(filePath)
        messageFile.fileUTI = fileUTI
        messageFile.isOffline = isOffline
        messageFile.messageId = messageId
        messageFile.opened = opened
        
        return createMessageAbstract(chat: chat, senderId: senderId, senderPublicKey: senderPublicKey, messageText: nil, messageFile: messageFile, messageCall: nil, tokMessageType: tokMessageType, dateInterval: dateInterval)
    }
    
    @discardableResult
    private func createMessageAbstract(chat: OCTChat,
                                       senderId: String?,
                                       senderPublicKey: String?,
                                       messageText: OCTMessageText?,
                                       messageFile: OCTMessageFile?,
                                       messageCall: OCTMessageCall?,
                                       tokMessageType: TokMessageType,
                                       dateInterval: TimeInterval = Date().timeIntervalSince1970) -> OCTMessageAbstract {
        let messageAbstract = OCTMessageAbstract()
        messageAbstract.dateInterval = dateInterval == 0 ? Date().timeIntervalSince1970 : dateInterval
        messageAbstract.senderUniqueIdentifier = senderId
        messageAbstract.chatUniqueIdentifier = chat.uniqueIdentifier
        messageAbstract.messageText = messageText
        messageAbstract.messageFile = messageFile
        messageAbstract.messageCall = messageCall
        messageAbstract.tokMessageType = tokMessageType
        
        if messageAbstract.senderUniqueIdentifier == nil || messageCall != nil {
            messageAbstract.readed = true
        }
        
        if let senderPublicKey = senderPublicKey {
            messageAbstract.senderPublicKey = senderPublicKey
        }
        
        autoreleasepool {
            let db = realmManager.database()
            db?.beginWriteTransaction()
            db?.add(messageAbstract)
            
            if chat.lastMessage == nil || messageAbstract.dateInterval > chat.lastActivityDateInterval {
                let needUpdateLastMessage = messageText?.messageType != 2 || messageFile != nil || messageCall != nil
                if needUpdateLastMessage {
                    chat.lastMessage = messageAbstract
                    chat.lastActivityDateInterval = messageAbstract.dateInterval
                }
            }
            
            try? db?.commitWriteTransaction()
        }
        
        return messageAbstract
    }
    
    private func addDefaultTipMessage(chat: OCTChat, in db: RLMRealm?) {
        let messageText = OCTMessageText()
        messageText.text = ""
        messageText.messageType = 2
        messageText.status = 1
        
        let defaultMessage = OCTMessageAbstract()
        defaultMessage.chatUniqueIdentifier = chat.uniqueIdentifier
        defaultMessage.dateInterval = 0
        defaultMessage.readed = true
        defaultMessage.messageText = messageText
        
        db?.add(defaultMessage)
    }
    
    func setTimeoutMessagesToFailure() {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "messageText.status == %d", 0),
                NSPredicate(format: "senderUniqueIdentifier == nil"),
                NSPredicate(format: "dateInterval < %f", (Date() - 5.minutes).timeIntervalSince1970)
                ])
            
            let results = OCTMessageAbstract.objects(in: db, with: predicate)
            let messages: [OCTMessageAbstract] = Results<OCTMessageAbstract>(results: results).toList()
            db.beginWriteTransaction()
            for message in messages {
                message.messageText?.status = 2
                message.messageFile?.fileType = .canceled
            }
            try? db.commitWriteTransaction()
        }
    }
    
    func findAllSendingMessages() -> [OCTMessageAbstract] {
        guard let db = realmManager.database() else {
            return []
        }
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "messageText.status == %d", 0),
            NSPredicate(format: "senderUniqueIdentifier == nil"),
            NSPredicate(format: "dateInterval >= %f", (Date() - 5.minutes).timeIntervalSince1970)
            ])
        let results = OCTMessageAbstract.objects(in: db, with: predicate).sortedResults(usingKeyPath: "dateInterval", ascending: true)
        
        let messages: [OCTMessageAbstract] = Results<OCTMessageAbstract>(results: results).toList()
        return messages
    }
    
    func deleteMessage(by id: String, withoutNotifying token: RLMNotificationToken? = nil) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            guard let messageAbstract = OCTMessageAbstract.object(in: db, forPrimaryKey: id) else {
                return
            }
            db.beginWriteTransaction()
            let chatId = messageAbstract.chatUniqueIdentifier
            let results = OCTMessageAbstract.objects(in: db, with: NSPredicate(format: "chatUniqueIdentifier == %@", chatId)).sortedResults(usingKeyPath: "dateInterval", ascending: false)
            let lastMessage = results.firstObject() as? OCTMessageAbstract
            let isLastMessage = lastMessage?.uniqueIdentifier == id
            db.delete(messageAbstract)
            
            if isLastMessage {
                let chat = OCTChat.object(in: db, forPrimaryKey: chatId)
                chat?.lastMessage = results.firstObject() as? OCTMessageAbstract
            }
            do {
                if let token = token {
                    try db.commitWriteTransactionWithoutNotifying([token])
                } else {
                    try db.commitWriteTransaction()
                }
            } catch {
                print("\(error)")
            }
        }
    }
    
    func setFileAsOpened(by id: String, withoutNotifying token: RLMNotificationToken?) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            guard let message = OCTMessageAbstract.object(in: db, forPrimaryKey: id) else {
                return
            }
            
            db.beginWriteTransaction()
            message.messageFile?.opened = true
            if let token = token {
                try? db.commitWriteTransactionWithoutNotifying([token])
            } else {
                try? db.commitWriteTransaction()
            }
        }
    }
    
    func change(chatId: String, enteredText: String) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            guard let chat = OCTChat.object(in: db, forPrimaryKey: chatId) else {
                return
            }
            db.beginWriteTransaction()
            chat.enteredText = enteredText
            try? db.commitWriteTransaction()
        }
    }
    
    func cancelPendingFiles() {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            let predicate = NSPredicate(format: "fileType == %d OR fileType == %d OR fileType == %d", OCTMessageFileType.waitingConfirmation.rawValue, OCTMessageFileType.loading.rawValue, OCTMessageFileType.paused.rawValue)
            let results = OCTMessageFile.objects(in: db, with: predicate) as! RLMResults<OCTMessageFile>
            guard results.count > 0 else { return }
            db.beginWriteTransaction()
            for i in 0..<results.count {
                let messageFile = results[i]
                messageFile.fileType = .canceled
            }
            try? db.commitWriteTransaction()
        }
    }
    
    func findAllMediaMessages(chatId: String) -> Results<OCTMessageAbstract> {
        let meidaTypes = ["public.jpeg", "public.png", "com.compuserve.gif", AVFileType.mp4.rawValue, AVFileType.mov.rawValue]
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "messageFile.fileUTI IN %@", meidaTypes),
            NSPredicate(format: "chatUniqueIdentifier == %@", chatId),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "messageFile.fileType == \(OCTMessageFileType.ready.rawValue)"),
                NSPredicate(format: "senderUniqueIdentifier == nil AND messageFile.fileType == \(OCTMessageFileType.canceled.rawValue)"),
                ])
            ])
        let results = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate).sortedResults(usingKeyPath: "dateInterval", ascending: true)
        return Results(results: results)
    }
    
    func markMessagesAsRead(inChat chatId: String) {
        autoreleasepool {
            guard let db = realmManager.database() else {
                return
            }
            guard let chat = OCTChat.object(in: db, forPrimaryKey: chatId) else {
                return
            }
            
            if chat.isGroup {
                db.beginWriteTransaction()
                chat.leftCount = 0
                try? db.commitWriteTransaction()
            } else {
                self.realmManager.markChatMessages(asRead: chatId, db: db)
            }
        }
    }
}

extension Database {
    func findLastMessage(withChatId uniqueIdentifier: String) -> (Bool, String?, String) {
        guard let chat = findChat(byId: uniqueIdentifier) else {
            return (false, nil, "")
        }
        if let enteredText = chat.enteredText, enteredText.isNotEmpty {
            return (true, nil, enteredText)
        }
        
        guard let message = chat.lastMessage else {
            return (false, nil, "")
        }
        
        var sender: String = ""
        if chat.isGroup {
            if message.senderPublicKey.isEmpty {
                sender = NSLocalizedString("You", comment: "")
            } else if let friend = findFriend(withPublicKey: message.senderPublicKey) {
                sender = friend.nickname
            } else if let peer = findPeer(withPublicKey: message.senderPublicKey) {
                sender = peer.nickname ?? ""
            }
            
            if sender.isNotEmpty {
                sender = sender + ": "
            }
        }
        if let text = message.messageText {
            if text.messageType == 0 {
                let content = sender + (text.text ?? "")
                return (false, nil, content)
            }
            return (false, nil, text.text ?? "")
        } else if let file = message.messageFile {
            let imageName = file.imageNameFromType()
            var text = ""
            switch imageName {
            case "MessageFile": text = file.fileName ?? "[File]"
            case "MessagePhoto": text = "[Photo]"
            case "MessageAudio": text = "[Audio]"
            case "MessageVideo": text = "[Video]"
            default: text = file.fileName ?? "[File]"
            }
            return (false, imageName, sender + text)
        } else if let _ = message.messageCall {
            return message.isOutgoing() ? (false, nil, "[Outgoing Call]") : (false, nil, "[Incoming Call]")
        }
        
        return (false, nil, "")
    }
    
    func normalChats(onlyGroup: Bool = false, predicate: NSPredicate? = nil) -> Results<OCTChat> {
        let db = realmManager.database()!
        
        #if DEBUG
        var predicates: [NSPredicate] = []
        #else
        var predicates: [NSPredicate] = [BotService.shared.groupBot, BotService.shared.findFriendBot]
                .compactMap { bot -> NSCompoundPredicate? in
                    guard let bot = bot, let botFriend = OCTFriend.objects(in: db, with: NSPredicate(format: "publicKey == %@", bot.publicKey)).firstObject() as? OCTFriend else {
                        return nil
                    }
                    let withoutBotsPredicate = NSPredicate(format: "ANY friends == %@ AND isGroup == NO", botFriend)
                    return NSCompoundPredicate(notPredicateWithSubpredicate: withoutBotsPredicate)
        }
        #endif
        
        if onlyGroup {
            let predicate = NSPredicate(format: "isGroup == YES")
            predicates.append(predicate)
        }
        if let predicate = predicate {
            predicates.append(predicate)
        }
        
        let rlmResults = OCTChat.objects(in: db, with: NSCompoundPredicate(andPredicateWithSubpredicates: predicates))
        return Results(results: rlmResults)
    }
    
    func findUnreadMessage(withChatId uniqueIdentifier: String) -> Results<OCTMessageAbstract> {
        let predicate = NSPredicate(format: "senderUniqueIdentifier != nil AND chatUniqueIdentifier == %@ AND readed == NO", uniqueIdentifier)
        let messages = OCTMessageAbstract.objects(in: realmManager.database(), with: predicate)
        return Results(results: messages)
    }
}

extension Database {
    @discardableResult
    func getOrCreatePeer(publicKey: String, groupNumber: UInt64, nickname: String?) -> OCTPeer {
        let friend = findFriend(withPublicKey: publicKey)
        let nickname = friend?.nickname ?? nickname
        let avatarData = friend?.avatarData
        
        guard let dbPeer = findPeer(withPublicKey: publicKey) else {
            let peer = OCTPeer()
            peer.publicKey = publicKey
            peer.groupNumber = Int(groupNumber)
            peer.nickname = nickname?.trim()
            peer.avatarData = avatarData
            add(object: peer)
            return peer
        }
        
        if let nickname = nickname?.trim(), nickname.isNotEmpty, nickname != dbPeer.nickname {
            update(object: dbPeer) { thePeer in
                thePeer.nickname = nickname
                thePeer.avatarData = avatarData
            }
        }
        return dbPeer
    }
    
    func peers(groupNumber: UInt64) -> Results<OCTPeer> {
        let predicate = NSPredicate(format: "groupNumber == %lld", groupNumber)
        let results = OCTPeer.objects(in: realmManager.database(), with: predicate)
        return Results(results: results)
    }
    
    func normalFriends() -> Results<OCTFriend> {
        #if DEBUG
        var predicates: [NSPredicate] = [] //BotService.shared.bots.map { NSPredicate(format: "publicKey != %@", $0.publicKey) }
        #else
        var predicates: [NSPredicate] = [BotService.shared.groupBot, BotService.shared.findFriendBot].map { NSPredicate(format: "publicKey != %@", $0.publicKey) }
        #endif
        predicates.append(NSPredicate(format: "friendState == %d", 0))
        
        let withoutBotsAndFriendsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let results = OCTFriend.objects(in: realmManager.database(), with: withoutBotsAndFriendsPredicate)
        return Results(results: results)
    }
    
    func isFindFriendBot(friendNumber: OCTToxFriendNumber) -> Bool {
        return self.findFriend(withPublicKey: BotService.shared.findFriendBot.publicKey)?.friendNumber == friendNumber
    }
    
    func isGroupBot(friendNumber: OCTToxFriendNumber) -> Bool {
        return self.findFriend(withPublicKey: BotService.shared.groupBot.publicKey)?.friendNumber == friendNumber
    }
    
    func isOfflineBot(friendNumber: OCTToxFriendNumber) -> Bool {
        return self.findFriend(withPublicKey: BotService.shared.offlineBot.publicKey)?.friendNumber == friendNumber
    }
    
    func isFileBot(friendNumber: OCTToxFriendNumber) -> Bool {
        return self.findFriend(withPublicKey: BotService.shared.fileBot.publicKey)?.friendNumber == friendNumber
    }
    
    func friend(with friendNumber: OCTToxFriendNumber, tox: OCTTox) -> OCTFriend? {
        do {
            let publicKey = try tox.publicKey(fromFriendNumber: friendNumber)
            return findFriend(withPublicKey: publicKey)
        } catch {
            return nil
        }
    }
    
    func friendNumber(publicKey: String, tox: OCTTox) throws -> OCTToxFriendNumber {
        var error: NSError?
        let friendNumber = tox.friendNumber(withPublicKey: publicKey, error: &error)
        if let err = error {
            throw err
        }
        return friendNumber
    }
    
    func clearFriendAvatar(with publicKey: String) {
        guard let friend = self.findFriend(withPublicKey: publicKey), friend.avatarData != nil else { return }
        update(object: friend) { theFriend in
            theFriend.avatarData = nil
        }
    }
    
    func blockUser(publicKey: String, isBlock: Bool) {
        if let friend = findFriend(withPublicKey: publicKey) {
            update(object: friend) { theFriend in
                theFriend.blocked = isBlock
            }
        }
        if let peer = findPeer(withPublicKey: publicKey) {
            update(object: peer) { thePeer in
                thePeer.blocked = isBlock
            }
        }
    }
}
