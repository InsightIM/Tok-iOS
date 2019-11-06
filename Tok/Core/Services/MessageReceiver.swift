//
//  MessageReceiver.swift
//  Tok
//
//  Created by Bryce on 2019/7/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt
import MobileCoreServices
import Chatto

enum GroupMessageType: UInt32 {
    case text = 0
    case file = 1
    case invite = 3
    case leave = 11
    case kickout = 13
    case dissolve = 16
}

class MessageReceiver {
    typealias PullResult = (chatId: String, up: Bool, tail: Bool, noMore: Bool, error: Bool)
    
    enum FetchMessageError: Error {
        case botNotFound
        case chatNotFound
        case messageNotFound
        case botNotConnected
    }
    
    private let disposeBag = DisposeBag()
    private let processQueue = DispatchQueue(label: "com.insight.messages.receiver.process")
    private let database: Database
    private let tokManager: TokManager
    private let fileManager: TokFileManager
    private let fileService: FileService
    
    private let pullLock = NSLock()
    private var pullRangeIds: Set<String>
    
    let joinedGroup = PublishSubject<Int64>()
    let didPullMessage = PublishSubject<PullResult>()
    let didReceiveGroupInfo = PublishSubject<GroupInfoModel>()
    
    init(tokManager: TokManager, database: Database, fileService: FileService) {
        self.tokManager = tokManager
        self.database = database
        self.fileManager = tokManager.fileManager
        self.fileService = fileService
        
        self.pullRangeIds = Set()
        
        database.cleanUnusedRanges()
        bindDelegate()
    }
    
    private func bindDelegate() {
        // friend message
        tokManager.rx.messageReceived()
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .filterMap { [unowned self] args -> FilterMap<(String, OCTFriend)> in
                let (messageData, friendNumber) = args
                guard !self.database.isFindFriendBot(friendNumber: friendNumber) else {
                    return .ignore
                }
                guard let friend = self.database.friend(with: friendNumber, tox: self.tokManager.tox),
                    let message = String(bytes: messageData, encoding: .utf8) else {
                        return .ignore
                }
                guard friend.blocked == false else {
                    return .ignore
                }
                return .map((message, friend))
        }
        .debug("friendMessageReceived")
        .subscribe(onNext: { [weak self] (text, friend) in
            guard let self = self else { return }
            let chat = self.database.findOrCreateChat(friend: friend)
            self.database.buildTextMessage(text: text, chat: chat, senderId: friend.uniqueIdentifier, senderPublicKey: friend.publicKey, status: 1, type: .normal, messageType: 0, messageId: -1, dateInterval: 0)
        })
            .disposed(by: disposeBag)
        
        // group message
        tokManager.rx.groupMessageReceived()
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .debug("groupMessageReceived")
            .subscribe(onNext: { [weak self] (cmd, data) in
                guard let self = self else { return }
                switch cmd {
                case .messageReadNotice:
                    self.handleReadNotice(data: data)
                case .inviteNotice:
                    self.handleGroupInvite(data: data, messageId: 0, createTime: Date().timeIntervalSince1970)
                case .errorNotice:
                    self.handleGroupErrorNotice(data: data)
                case .acceptJoinRequest:
                    self.handleGroupJoinRequest(data: data)
                case .pullResponse:
                    self.handleGroupPullResponse(data: data)
                case .infoResponse:
                    self.handleGroupInfo(data: data)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
        
        // stranger callback
        tokManager.rx.strangerMessageReceived()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (strangerCmd, data) in
                switch strangerCmd {
                case .getListResponse:
                    NotificationCenter.default.post(name: NSNotification.Name(kOCTStrangerMessageReceivedNotification), object: data)
                case .signatureResponse:
                    NotificationCenter.default.post(name: NSNotification.Name(kOCTStrangerSignatureReceivedNotification), object: data)
                default: break
                }
            })
            .disposed(by: disposeBag)
        
        // offline callback
        tokManager.rx.offlineMessageReceived()
            .observeOn(SerialDispatchQueueScheduler(queue: processQueue, internalSerialQueueName: processQueue.label))
            .debug("offlineMessageReceived")
            .subscribe(onNext: { [weak self] (friendNumber, cmd, data) in
                guard let self = self else { return }
                switch cmd {
                case .pullResponse:
                    self.handleOfflineMessage(data: data)
                case .readNotice:
                    let model = OfflineMessagePullReq()
                    self.tokManager.tox.sendOfflineMessage(withBotFriendNumber: friendNumber, offlineCmd: .pullRequest, messageId: -1, message: model.data(), error: nil)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Pull

extension MessageReceiver {
    private func buildPullRequestId(chatId: String, startMsgId: Int64, endMsgId: Int64) -> String {
        return "\(chatId)_\(startMsgId)_\(endMsgId)"
    }
    
    func pullGroupMessagesIfNeeded(chatId: String, startTimeInterval: TimeInterval, endTimeInterval: TimeInterval, up: Bool, tail: Bool, pageSize: Int) {
        guard let chat = self.database.findChat(byId: chatId), chat.isGroup else {
            didPullMessage.onNext(PullResult(chatId, up, tail, false, true))
            return
        }
        guard let bot = self.database.findFriend(withPublicKey: BotService.shared.groupBot.publicKey), bot.isConnected else {
            didPullMessage.onNext(PullResult(chatId, up, tail, false, true))
            return
        }
        
        let dateInterval: TimeInterval = up ? startTimeInterval : endTimeInterval
        var closestRange: OCTRange?
        if tail {
            closestRange = self.database.findLatestRange(chatId: chatId)
        } else {
            closestRange = self.findClosestRange(up: up, chatId: chatId, dateInterval: dateInterval)
        }
        
        guard let range = closestRange else {
            didPullMessage.onNext(PullResult(chatId, up, tail, true, false))
            return
        }
        let groupNumber: UInt64 = UInt64(chat.groupNumber)
        
        let unpullRanges: [OCTRange] = database.findRanges(chatId: chatId, startTimeInterval: startTimeInterval, endTimeInterval: endTimeInterval).toList()
        for range in unpullRanges {
            let id = buildPullRequestId(chatId: chatId, startMsgId: range.startMessageId, endMsgId: range.endMessageId)
            if pullRangeIds.contains(id) {
                print("🔐 pullRangeIds.contains(\(range.uniqueIdentifier!))")
                continue
            }
            print("🔐🔐 pullRangeIds.insert(\(id))")
            pullLock.lock()
            pullRangeIds.insert(id)
            pullLock.unlock()
            
            let startMsgId = UInt64(max(range.startMessageId, 0))
            let endMsgId = UInt64(max(range.endMessageId, 0))
            sendPull(by: groupNumber, groupFriendNumber: bot.friendNumber, startMsgId: startMsgId, endMsgId: endMsgId, up: up, tail: false, count: 50)
        }
        
        let timeInterval = tail ? Date().timeIntervalSince1970 : dateInterval
        let messageCount = database.findMessagesCount(chatId: chatId, range: range, dateInterval: timeInterval, up: up)
        guard messageCount < pageSize else {
            didPullMessage.onNext(PullResult(chatId, up, tail, false, false))
            return
        }
        
        guard range.isInvalidated == false else { return }
        let startMsgId = UInt64(max(range.startMessageId, 0))
        let endMsgId = UInt64(max(range.endMessageId, 0))
        
        self.sendPull(by: groupNumber, groupFriendNumber: bot.friendNumber, startMsgId: startMsgId, endMsgId: endMsgId, up: up, tail: tail, count: pageSize)
    }
    
    private func updateRangeIfNeeded(chatId: String, messages: [GroupRealMsg], up: Bool) {
        let minMessage = messages.min { $0.msgId < $1.msgId }
        let maxMessage = messages.max { $0.msgId < $1.msgId }
        
        guard let earliestMessage = minMessage, let latestMessage = maxMessage else {
            return
        }
        #if DEBUG
        print("minMessage: \(earliestMessage.msgId) | maxMessage: \(latestMessage.msgId)")
        #endif
        
        if let coveredRange = database.findCoveredRange(chatId: chatId, startId: min(earliestMessage.prevMsgId, earliestMessage.msgId), endId: latestMessage.msgId) {
            #if DEBUG
            print("🏷 Delete range. startMessageId:\(coveredRange.startMessageId), endMessageId: \(coveredRange.endMessageId)")
            #endif
            let rangeId = coveredRange.uniqueIdentifier!
            database.deleteRange(rangeId: rangeId)
            return
        }
        
        if up {
            guard let range = database.findUpRange(chatId: chatId, maxMsgId: latestMessage.msgId, nextMsgId: latestMessage.nextMsgId) else {
                #if DEBUG
                print("❌ up range not found")
                #endif
                return
            }
            #if DEBUG
            print("🏷 Update ⬆️ range. startMessageId:\(range.startMessageId) endMessageId: \(range.endMessageId). 🆕 newEndMessage: \(earliestMessage)")
            #endif
            database.update(object: range, block: { theRange in
                theRange.endMessageId = Int64(earliestMessage.prevMsgId)
                theRange.endTimeInterval = Double(earliestMessage.createTime) / 1000.0
            })
        } else {
            guard let range = database.findDownRange(chatId: chatId, minPreId: min(earliestMessage.prevMsgId, earliestMessage.msgId)) else {
                return
            }
            database.update(object: range, block: { theRange in
                theRange.startMessageId = Int64(latestMessage.msgId)
                theRange.startTimeInterval = Double(latestMessage.createTime) / 1000.0
            })
        }
    }
    
    private func findClosestRange(up: Bool, chatId: String, dateInterval: TimeInterval) -> OCTRange? {
        if up {
            let startTimeInterval = dateInterval
            let range = database.findUpClosestRange(chatId: chatId, startTimeInterval: startTimeInterval)
            return range
        }
        
        let endTimeInterval = dateInterval
        let range = database.findDownClosestRange(chatId: chatId, endTimeInterval: endTimeInterval)
        return range
    }
    
    private func sendPull(by groupId: UInt64, groupFriendNumber: OCTToxFriendNumber, startMsgId: UInt64, endMsgId: UInt64, up: Bool, tail: Bool, count: Int) {
        let pull = GroupMessagePullNewReq()
        pull.groupId = groupId
        pull.direction = up ? 1 : 0
        pull.tail = tail ? 1 : 0
        pull.startMsgId = startMsgId
        pull.endMsgId = endMsgId
        pull.count = UInt32(max(count, 0))
        
        print("Pull \(pull)")
        
        tokManager.tox.sendGroupMessage(withBotFriendNumber: groupFriendNumber,
                                        groupCmd: .pullRequest,
                                        messageId: -1,
                                        message: pull.data(),
                                        error: nil)
    }
}

// MARK: - Handle Group Message

private extension MessageReceiver {
    private func fetchGroupInfo(_ groupId: UInt64) {
        let model = GroupInfoReq()
        model.groupId = groupId
        
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: tokManager.tox) else {
            return
        }
        self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: .info, messageId: -1, message: model.data(), error: nil)
    }
    
    func handleReadNotice(data: Data) {
        guard let model = try? GroupMessageReadNotice(data: data) else {
            return
        }
        let array = model.msgsReadArray as! [GroupMessageRead]
        for notice in array {
            var groupChat: OCTChat? = self.database.findGroupChat(by: notice.groupId)
            if let message = notice.lastMsg,
                let msgType = GroupMessageType(rawValue: message.msgType),
                [GroupMessageType.text, GroupMessageType.file, GroupMessageType.invite].contains(msgType) {
                if groupChat == nil {
                    groupChat = self.database.findOrCreateGroupChat(by: notice.groupId)
                    fetchGroupInfo(notice.groupId)
                }
            }
            
            if let message = notice.lastMsg {
                handleGroupMessage(message, tokMessageType: .tempGroupMessage)
            }
            
            guard let chat = groupChat else { continue }
            
            if let lastMsg = notice.lastMsg, lastMsg.msgId > chat.lastMessageId {
                let endMessageId = Int64(lastMsg.msgId)
                let endTimeInterval = Double(lastMsg.createTime) / 1000.0
                if let lastRange = self.database.findRange(endMessageId: chat.lastMessageId) {
                    self.database.update(object: lastRange) { theRange in
                        theRange.endMessageId = endMessageId
                        theRange.endTimeInterval = endTimeInterval
                    }
                } else {
                    let localLastMessage = self.database.findChatLatestMessage(chatId: chat.uniqueIdentifier)
                    
                    let range = OCTRange()
                    range.chatUniqueIdentifier = chat.uniqueIdentifier
                    range.endTimeInterval = endTimeInterval
                    range.endMessageId = endMessageId
                    range.startTimeInterval = localLastMessage?.dateInterval ?? 0
                    range.startMessageId = chat.lastMessageId
                    
                    self.database.add(object: range)
                    #if DEBUG
                    print("❤️Create range. startMessageId:\(range.startMessageId). endMessageId: \(lastMsg.msgId)")
                    #endif
                }
                
                // Update Chat lastMessageId
                self.database.update(object: chat, block: { theChat in
                    theChat.lastMessageId = Int64(notice.latestMsgId)
                    theChat.leftCount = Int(notice.leftCount)
                })
            }
            
            NotificationCenter.default.post(name: .NewMessagesDidReceive, object: chat.uniqueIdentifier)
        }
    }
    
    func handleGroupErrorNotice(data: Data) {
        guard let model = try? GroupErrorNotice(data: data) else {
            return
        }
        if model.code == 4 {
            joinedGroup.onNext(Int64(model.groupId))
            return
        }
        
        guard let chat = self.database.findGroupChat(by: model.groupId) else {
            return
        }
        /** 1: not group member; 2: not group owner; 3: group is not exist; 4: is group member already */
        let disableChat: () -> Void = {
            self.database.update(object: chat, block: { theChat in
                theChat.groupStatus = 1 // disabled
            })
        }
        
        var message: String?
        if model.code == 1 {
            disableChat()
            message = NSLocalizedString("You were removed from this group", comment: "")
        } else if model.code == 3 {
            disableChat()
            message = NSLocalizedString("Group was dissolved", comment: "")
        }
        if let text = message {
            self.database.buildTextMessage(text: text, chat: chat, senderId: nil, senderPublicKey: nil, status: 1, type: .group, messageType: 1, messageId: -1, dateInterval: 0)
        }
    }
}

// MARK: - Ranges

private extension MessageReceiver {
    
    func handleGroupInfo(data: Data) {
        guard let model = try? GroupInfoRes(data: data) else {
            return
        }
        guard let title = String(data: model.groupName, encoding: .utf8), title.isNotEmpty else {
            return
        }
        
        let ownerPk = OCTTox.bin(toHexString: model.ownerPk)
        let membersNum = model.membersNum
        let desc = String(data: model.remark, encoding: .utf8)
        let shareId = String(data: model.shareId, encoding: .utf8)
        let type = model.type
        let muted = model.status == 1
        
        if let chat = self.database.findGroupChat(by: model.groupId) {
            self.database.update(object: chat, block: { theChat in
                if let ownerPk = ownerPk {
                    theChat.ownerPublicKey = ownerPk
                }
                theChat.title = title
                theChat.groupDescription = desc
                theChat.groupId = shareId
                theChat.isMute = muted
                theChat.groupType = Int(type)
                theChat.groupMemebersCount = Int(membersNum)
            })
        }
        
        let infoModel = GroupInfoModel(groupId: Int64(model.groupId), title: title, ownerPk: ownerPk, membersNum: Int(membersNum), desc: desc, shareId: shareId, type: Int(type), muted: muted)
        didReceiveGroupInfo.onNext(infoModel)
    }
    
    func handleGroupPullResponse(data: Data) {
        guard let model = try? GroupMessagePullNewRes(data: data) else {
            return
        }
        guard let chat = self.database.findOrCreateGroupChat(by: model.groupId) else {
            return
        }
        if chat.groupStatus != 0 {
            database.update(object: chat, block: { theChat in
                theChat.groupStatus = 0
            })
        }
        
        let up = model.direction == 1
        let chatId = chat.uniqueIdentifier!
        guard let messageArray = model.msgArray as? [GroupRealMsg] else {
            self.didPullMessage.onNext(PullResult(chatId, up, model.tail == 1, false, true))
            return
        }
        
        updateRangeIfNeeded(chatId: chatId, messages: messageArray, up: up)
        
        messageArray.forEach { message in
            handleGroupMessage(message, tokMessageType: .normal)
        }
        
        if model.end == 1 {
            let id = buildPullRequestId(chatId: chatId, startMsgId: Int64(model.startMsgId), endMsgId: Int64(model.endMsgId))
            print("🔐 pullRangeIds.remove(\(id))")
            pullLock.lock()
            pullRangeIds.remove(id)
            pullLock.unlock()
            
            self.didPullMessage.onNext(PullResult(chatId, up, model.tail == 1, false, false))
            print("😛😛😛😛😛😛Pull End, Pull again.")
        }
    }
    
    func handleGroupMessage(_ message: GroupRealMsg, tokMessageType: TokMessageType) {
//        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: tokManager.tox) else {
//            return
//        }
        guard let fileFriendNumber = try? database.friendNumber(publicKey: BotService.shared.fileBot.publicKey, tox: tokManager.tox) else {
            return
        }
        guard let msgType = GroupMessageType(rawValue: message.msgType) else {
            return
        }
        
        let isTextExist: () -> Bool = {
            return self.database.isExist(textMessage: OCTToxMessageId(message.msgId))
        }
        let isFileExist: () -> Bool = {
            return self.database.isExist(fileMessage: OCTToxMessageId(message.msgId))
        }
        
        switch msgType {
        case .text:
            guard !isTextExist() else { return }
            handleGroupTextMessage(message, tokMessageType: tokMessageType)
        case .file:
            guard !isFileExist() else { return }
            let messageAbstract = handleGroupFileMessage(message, tokMessageType: tokMessageType)
            if let message = messageAbstract {
                fileService.enqueue(messageAbstract: message, friendNumber: fileFriendNumber)
            }
        default:
            guard !isTextExist() else { return }
            handleGroupNotices(message: message)
        }
    }
    
    func handleGroupTextMessage(_ message: GroupRealMsg, tokMessageType: TokMessageType) {
        guard let publicKey = String(bytes: message.frPk, encoding: .utf8), publicKey != tokManager.tox.publicKey else {
            return
        }
        guard let text = String(bytes: message.msg, encoding: .utf8) else {
            return
        }
        
        let nickname = String(bytes: message.frName, encoding: .utf8)
        let sender = database.getOrCreatePeer(publicKey: publicKey, groupNumber: message.groupId, nickname: nickname)
        guard sender.blocked == false else {
            return
        }
        
        guard let chat = self.database.findGroupChat(by: message.groupId) else {
            return
        }
        
        let dateInterval = Double(message.createTime) / 1000.0
        
        database.buildTextMessage(text: text, chat: chat, senderId: sender.uniqueIdentifier, senderPublicKey: sender.publicKey, status: 1, type: .group, messageType: 0, messageId: OCTToxMessageId(message.msgId), dateInterval: dateInterval, tokMessageType: tokMessageType)
    }
    
    func handleGroupFileMessage(_ message: GroupRealMsg, tokMessageType: TokMessageType) -> OCTMessageAbstract? {
        guard let publicKey = String(bytes: message.frPk, encoding: .utf8), publicKey != tokManager.tox.publicKey else {
            return nil
        }
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.fileBot.publicKey, tox: self.tokManager.tox) else {
            return nil
        }
        
        let nickname = String(data: message.frName, encoding: .utf8)
        let peer = database.getOrCreatePeer(publicKey: publicKey, groupNumber: message.groupId, nickname: nickname)
        guard peer.blocked == false else {
            return nil
        }
        
        let displayName = String(data: message.fileDisplayName, encoding: .utf8)
        let fileName = String(data: message.fileName, encoding: .utf8)
        
        guard let fileDisplayName = displayName?.isNotEmpty == true ? displayName : fileName else {
            return nil
        }
        guard let chat = self.database.findGroupChat(by: message.groupId) else {
            return nil
        }
        
        let messageId = message.msgId
        let fileSize = message.fileSize
        let createTime = Double(message.createTime) / 1000.0
        
        return fileService.saveFileMessage(fileNumber: Int32.max, friendNumber: friendNumber, fileSize: OCTToxFileSize(fileSize),
                                           fileDisplayName: fileDisplayName, senderId: peer.uniqueIdentifier, senderPublicKey: peer.publicKey, chat: chat, dateInterval: createTime, isOffline: true, messageId: OCTToxMessageId(messageId), tokMessageType: tokMessageType)
    }
    
    func handleGroupNotices(message: GroupRealMsg) {
        guard let msgType = GroupMessageType(rawValue: message.msgType) else {
            return
        }
        
        let createTime = Double(message.createTime) / 1000.0
        switch msgType {
        case .invite:
            handleGroupInvite(data: message.msg, messageId: message.msgId, createTime: createTime)
        case .leave:
            handleGroupLeave(data: message.msg, messageId: message.msgId, createTime: createTime)
        case .kickout:
            handleGroupKickout(data: message.msg, messageId: message.msgId, createTime: createTime)
        case .dissolve:
            handleGroupDisslove(data: message.msg, messageId: message.msgId, createTime: createTime)
        default: break
        }
    }
    
    func handleGroupInvite(data: Data, messageId: UInt64, createTime: Double) {
        guard let model = try? GroupInviteNotice(data: data) else {
            return
        }
        
        let inviterPk = String(data: model.inviterPk, encoding: .utf8)
        let inviteePk = String(data: model.inviteePk, encoding: .utf8)
        
        let inviterName = String(data: model.inviterName, encoding: .utf8)
        let inviteeName = String(data: model.inviteeName, encoding: .utf8)
        
        var message: String?
        switch model.code {
        case 0:
            guard let inviteePk = inviteePk, let friend = database.findFriend(withPublicKey: inviteePk) else {
                return
            }
            guard let chat = database.findGroupChat(by: model.groupId) else {
                return
            }
            let text = String(format: NSLocalizedString("%@'s app version is too low to be invited", comment: ""), friend.nickname)
            database.buildTextMessage(text: text, chat: chat, senderId: nil, senderPublicKey: nil, status: 1, type: .group, messageType: 1, messageId: OCTToxMessageId(messageId), dateInterval: 0)
        case 1:
            var saveMessage = false
            let selfPublicKey = tokManager.tox.publicKey
            if inviterPk == nil || inviterPk?.isEmpty == true {
                if inviteePk?.uppercased() == selfPublicKey {
                    joinedGroup.onNext(Int64(model.groupId))
                    return
                } else if let inviteeName = inviteeName {
                    message = String(format: NSLocalizedString("%@ joined group", comment: ""), inviteeName)
                }
            } else if inviteePk?.uppercased() == selfPublicKey {
                guard let inviterName = inviterName else { return }
                message = String(format: NSLocalizedString("%@ invited you to the group chat", comment: ""), inviterName)
                saveMessage = true
            } else if inviterPk?.uppercased() == selfPublicKey {
                guard let inviteeName = inviteeName else { return }
                message = String(format: NSLocalizedString("You invited %@ to the group chat", comment: ""), inviteeName)
                saveMessage = true
            } else {
                guard let inviteeName = inviteeName, let inviterName = inviterName, inviteeName.isNotEmpty, inviterName.isNotEmpty else { return }
                message = String(format: NSLocalizedString("%@ invited %@ to the group chat", comment: ""), inviterName, inviteeName)
            }
            
            guard let text = message else {
                return
            }
            guard let chat = self.database.findGroupChat(by: model.groupId) else {
                return
            }
            guard chat.groupType != 1 || saveMessage else { // ignore public group joined message
                return
            }
            database.buildTextMessage(text: text, chat: chat, senderId: nil, senderPublicKey: nil, status: 1, type: .group, messageType: 1, messageId: OCTToxMessageId(messageId), dateInterval: createTime)
        case 2:
            joinedGroup.onError(NSError()) // cannot join group, because be blocked
        default: break
        }
    }
    
    func handleGroupLeave(data: Data, messageId: UInt64, createTime: Double) {
        guard let model = try? GroupLeaveNotice.parse(from: data) else {
            return
        }
        guard let chat = database.findGroupChat(by: model.groupId) else {
            return
        }
        guard let peerName = String(data: model.peerName, encoding: .utf8) else {
            return
        }
        guard chat.groupType != 1 else { // ignore public group leave message
            return
        }
        
        let message = String(format: NSLocalizedString("%@ left", comment: ""), peerName)
        database.buildTextMessage(text: message, chat: chat, senderId: nil, senderPublicKey: nil, status: 1, type: .group, messageType: 1, messageId: OCTToxMessageId(messageId), dateInterval: createTime)
    }
    
    func handleGroupKickout(data: Data, messageId: UInt64, createTime: Double) {
        guard let model = try? GroupKickoutNotice.parse(from: data) else {
            return
        }
        guard let chat = database.findGroupChat(by: model.groupId) else {
            return
        }
        guard let peerName = String(data: model.peerName, encoding: .utf8) else {
            return
        }
        guard let peerPublicKey = String(data: model.peerPk, encoding: .utf8) else {
            return
        }
        
        let selfPublicKey = tokManager.tox.publicKey
        var message: String
        if peerPublicKey.uppercased() == selfPublicKey {
            guard createTime > chat.lastActivityDateInterval else { return }
            message = NSLocalizedString("You were removed from this group", comment: "")
            database.update(object: chat) { theChat in
                theChat.groupStatus = 2
            }
        } else {
            message = String(format: NSLocalizedString("%@ was removed from this group", comment: ""), peerName)
        }
        database.buildTextMessage(text: message, chat: chat, senderId: nil, senderPublicKey: nil, status: 1, type: .group, messageType: 1, messageId: OCTToxMessageId(messageId), dateInterval: createTime)
    }
    
    func handleGroupDisslove(data: Data, messageId: UInt64, createTime: Double) {
        guard let model = try? GroupDismissNotice.parse(from: data) else {
            return
        }
        guard let chat = database.findGroupChat(by: model.groupId) else {
            return
        }
        
        database.update(object: chat) { theChat in
            theChat.groupStatus = 2
        }
        
        let message = NSLocalizedString("Group was dissolved", comment: "")
        database.buildTextMessage(text: message, chat: chat, senderId: nil, senderPublicKey: nil, status: 1, type: .group, messageType: 1, messageId: OCTToxMessageId(messageId), dateInterval: createTime)
    }
    
    func handleGroupJoinRequest(data: Data) {
        guard let message = try? GroupAcceptJoinRequest(data: data) else {
            return
        }
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: tokManager.tox) else {
            return
        }
        let infos = message.infoArray as! [GroupAcceptJoinInfo]
        let nobody = UserDefaultsManager().joinGroupSettingNobody
        for model in infos {
            guard !nobody else {
                sendAcceptJoinResponse(groupId: model.groupId, result: 1, groupFriendNumber: friendNumber)
                return
            }
            
            guard let inviterPk = String(data: model.inviterPk, encoding: .utf8) else {
                return
            }
            let friend = database.findFriend(withPublicKey: inviterPk, friendState: Database.FriendState.accepted)
            let result: UInt32 = friend == nil ? 1 : 0
            sendAcceptJoinResponse(groupId: model.groupId, result: result, groupFriendNumber: friendNumber)
            
            guard result == 0 else {
                return
            }
            guard let chat = database.findGroupChat(by: model.groupId) else {
                return
            }
            database.update(object: chat) { theChat in
                theChat.title = String(data: model.groupTitle, encoding: .utf8)
                theChat.groupDescription = String(data: model.groupRemark, encoding: .utf8)
            }
        }
    }
    
    func sendAcceptJoinResponse(groupId: UInt64, result: UInt32, groupFriendNumber: OCTToxFriendNumber) {
        let model = GroupAcceptJoinResponse()
        model.groupId = groupId
        model.result = result
        tokManager.tox.sendGroupMessage(withBotFriendNumber: groupFriendNumber,
                                        groupCmd: .acceptJoinResponse,
                                        messageId: -1,
                                        message: model.data(),
                                        error: nil)
    }
}

// MARK: - Offline message

private extension MessageReceiver {
    enum OfflineMessageType: UInt32 {
        case text = 0
        case file = 1
        case friendRequest = 2
        case acceptFriendRequest = 3
    }
    
    func handleOfflineMessage(data: Data) {
        guard let model = try? OfflineMessagePullRes(data: data) else {
            return
        }
        guard let messageArray = model.msgArray as? [OfflineMessage] else {
            return
        }
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.offlineBot.publicKey, tox: tokManager.tox) else {
            return
        }
        
        var maxMsgId: UInt64 = 0
        messageArray.forEach { message in
            maxMsgId = max(message.msgId, maxMsgId)
            guard let msgType = OfflineMessageType(rawValue: message.msgType) else {
                return
            }
            guard let publicKey = String(data: message.frPk, encoding: .utf8),
                let friend = database.findFriend(withPublicKey: publicKey),
                friend.blocked == false else {
                    return
            }
            
            switch msgType {
            case .text:
                handleOfflineTextMessage(message: message)
            case .file:
                let messageAbstract = handleOfflineFileMessage(message: message)
                if let message = messageAbstract {
                    fileService.enqueue(messageAbstract: message, friendNumber: friendNumber)
                }
            case .friendRequest:
                handleOfflineFriendRequest(message: message)
            case .acceptFriendRequest:
                handleOfflineAcceptFriendRequest(message: message)
            }
        }
        
        guard messageArray.count > 0 else {
            return
        }
        guard maxMsgId > 0 else {
            return
        }
        sendDel(lastMsgId: maxMsgId, offlineBotFriendNumber: friendNumber)
    }
    
    func handleOfflineTextMessage(message: OfflineMessage) {
        guard !database.isExist(textMessage: OCTToxMessageId(message.msgId)) else {
            return
        }
        guard let publicKey = String(data: message.frPk, encoding: .utf8),
            let friend = database.findFriend(withPublicKey: publicKey) else {
                return
        }
        guard let data = tokManager.tox.decryptOfflineMessage(message.content, friendNumber: friend.friendNumber),
            let text = String(data: data, encoding: .utf8) else {
                return
        }
        
        let dateInterval = Double(message.createTime) / 1000.0
        
        let chat = database.findOrCreateChat(friend: friend)
        database.buildTextMessage(text: text, chat: chat, senderId: friend.uniqueIdentifier, senderPublicKey: friend.publicKey, status: 1, type: .offline, messageType: 0, messageId: OCTToxMessageId(message.msgId), dateInterval: dateInterval)
    }
    
    func handleOfflineFileMessage(message: OfflineMessage) -> OCTMessageAbstract? {
        guard !database.isExist(fileMessage: OCTToxMessageId(message.msgId)) else {
            return nil
        }
        guard let publicKey = String(data: message.frPk, encoding: .utf8),
            let friend = database.findFriend(withPublicKey: publicKey) else {
                return nil
        }
        guard let fileDisplayName = String(data: message.fileDisplayName, encoding: .utf8) else {
            return nil
        }
        
        let friendNumber = friend.friendNumber
        let messageId = message.msgId
        let fileSize = message.fileSize
        let createTime = Double(message.createTime) / 1000.0
        let chat = database.findOrCreateChat(friend: friend)
        
        return fileService.saveFileMessage(fileNumber: Int32.max, friendNumber: friendNumber, fileSize: OCTToxFileSize(fileSize),
                                           fileDisplayName: fileDisplayName, senderId: friend.uniqueIdentifier, senderPublicKey: friend.publicKey, chat: chat, dateInterval: createTime, isOffline: true, messageId: OCTToxMessageId(messageId), tokMessageType: .normal)
    }
    
    func handleOfflineFriendRequest(message: OfflineMessage) {
        guard let publicKey = String(data: message.frPk, encoding: .utf8) else {
            return
        }
        
        if let _ = database.findFriend(withPublicKey: publicKey, friendState: .accepted) {
            sendAcceptOfflineRequest(publicKey: publicKey)
        } else {
            let info = String(data: message.content, encoding: .utf8)
            database.addFriendRequest(message: info, publicKey: publicKey, isOutgoing: false)
        }
    }
    
    func handleOfflineAcceptFriendRequest(message: OfflineMessage) {
        guard let publicKey = String(data: message.frPk, encoding: .utf8) else {
            return
        }
        database.friendAcceptRequest(publicKey: publicKey)
    }
    
    func sendDel(lastMsgId: UInt64, offlineBotFriendNumber: OCTToxFriendNumber) {
        let del = OfflineMessageDelReq()
        del.lastMsgId = lastMsgId
        tokManager.tox.sendOfflineMessage(withBotFriendNumber: offlineBotFriendNumber,
                                          offlineCmd: .delRequest,
                                          messageId: -1,
                                          message: del.data(),
                                          error: nil)
    }
    
    func sendAcceptOfflineRequest(publicKey: String) {
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.offlineBot.publicKey, tox: tokManager.tox) else {
            return
        }
        
        let messageId = tokManager.tox.generateMessageId()
        let model = OfflineMessageReq()
        model.localMsgId = messageId
        model.toPk = publicKey.data(using: .utf8)
        model.msgType = 3
        
        tokManager.tox.sendOfflineMessage(withBotFriendNumber: friendNumber, offlineCmd: .send, messageId: messageId, message: model.data(), error: nil)
    }
}

extension String {
    func fileUTI() -> String? {
        let fileExtension = (self as NSString).pathExtension
        let unmanagedIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)
        let fileUTI = unmanagedIdentifier?.takeRetainedValue() as String?
        return fileUTI
    }
}
