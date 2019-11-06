//
//  MessageService.swift
//  Tok
//
//  Created by Bryce on 2019/8/10.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxSwiftExt

struct Peer {
    let nickname: String
    let publicKey: String
    let confirmFlag: UInt32
    let avatar: UIImage?
}

struct GroupInfoModel {
    let groupId: Int64
    let title: String
    let ownerPk: String?
    let membersNum: Int
    let desc: String?
    let shareId: String?
    let type: Int
    let muted: Bool
}

class MessageService {
    private let disposeBag = DisposeBag()
    private let sendingQueue = DispatchQueue(label: "com.insight.messages.service.sending")
    
    let tokManager: TokManager
    let messageSender: MessagesSender
    let messageReceiver: MessageReceiver
    let fileService: FileService
    let database: Database
    let friendService: FriendService
    let nameManager: NameManager
    
    init(tokManager: TokManager) {
        self.tokManager = tokManager
        self.database = Database(realmManager: tokManager.toxManager.managerGetRealmManager())
        self.fileService = FileService(tokManager: tokManager, database: database)
        self.messageSender = MessagesSender(tokManager: tokManager, database: database, fileService: fileService)
        self.messageReceiver = MessageReceiver(tokManager: tokManager, database: database, fileService: fileService)
        self.friendService = FriendService(toxManager: tokManager.toxManager, database: database)
        self.nameManager = NameManager(database: database)
    }
    
    func markAllMessagesAsRead(chatId: String) {
        DispatchQueue.global().async {
            self.database.markMessagesAsRead(inChat: chatId)
        }
    }
    
    func markMessageAsRead(id: String) {
        DispatchQueue.global().async {
            guard let message = self.database.findMessage(by: id),
                !message.readed else {
                    return
            }
            self.database.update(object: message) { theMessage in
                theMessage.readed = true
            }
            guard let chat = self.database.findChat(byId: message.chatUniqueIdentifier), chat.isGroup else {
                return
            }
            self.database.update(object: chat, block: { theChat in
                theChat.leftCount = max(theChat.leftCount - 1, 0)
            })
        }
    }
    
    func setAudioAsReaded(id: String, withoutNotifying token: RLMNotificationToken?) {
        DispatchQueue.global().async {
            self.database.setFileAsOpened(by: id, withoutNotifying: token)
        }
    }
    
    func cancelFileMessage(id: String, isIncoming: Bool) {
        DispatchQueue.global().async {
            self.fileService.cancel(id: id, isIncoming: isIncoming)
        }
    }
    
    func change(chatId: String, enteredText: String) {
        DispatchQueue.global().async {
            self.database.change(chatId: chatId, enteredText: enteredText)
        }
    }
    
    func matchGroupShareId(text: String) -> String? {
        guard let shareId = text.matchGroupShareIdString(), let groupNumber = shareId.matchGroupNumber() else {
            return nil
        }
        guard database.findGroupChat(by: UInt64(groupNumber)) == nil else {
            return nil
        }
        return shareId
    }
    
    func matchNewFriendCommand(text: String) -> String? {
        guard let address = text.matchCommandString() else {
            return nil
        }
        // it's not your public key
        guard address != tokManager.toxManager.user.userAddress.uppercased() else {
            return nil
        }
        // it's not friend public key
        let pk = (address as NSString).substring(to: Int(kOCTToxPublicKeyLength))
        guard database.findFriend(withPublicKey: pk) == nil else {
            return nil
        }
        return address
    }
}

// MARK - Group

extension MessageService {
    enum GroupInfoError: Error {
        case wrongData
        case wrongShareId
    }
    
    func createGroup(name: String, groupType: Int) -> Observable<Int> {
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: tokManager.tox) else {
            return .error(GroupInfoError.wrongData)
        }
        
        return Observable.just((), scheduler: SerialDispatchQueueScheduler(queue: sendingQueue, internalSerialQueueName: sendingQueue.label))
            .flatMap { [unowned self] _ -> Observable<Void> in
                let model = GroupCreateReq()
                model.groupName = name.data(using: .utf8)
                model.type = UInt32(groupType)
                
                var error: NSError?
                self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: .create, messageId: -1, message: model.data(), error: &error)
                guard error == nil else {
                    return .error(GroupInfoError.wrongData)
                }
                return .just(())
            }
            .observeOn(MainScheduler.instance)
            .flatMap { [unowned self] in
                self.tokManager.rx.groupMessageReceived()
            }
            .filterMap { [weak self] args -> FilterMap<Int> in
                guard let self = self else { return .ignore }
                let (groupCmd, data) = args
                guard groupCmd == OCTToxGroupCmd.createResponse else {
                    return .ignore
                }
                guard let model = try? GroupCreateRes(data: data) else {
                    return .ignore
                }
                guard let chat = self.database.findOrCreateGroupChat(by: model.groupId) else {
                    return .ignore
                }
                return .map(chat.groupNumber)
            }
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .take(1)
            .debug("Create group")
    }
    
    func fetch(groupInfo id: UInt64) -> Observable<GroupInfoModel> {
        guard let friendNumber = try? database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: tokManager.tox) else {
            return .error(GroupInfoError.wrongData)
        }
        
        return Observable.just((), scheduler: SerialDispatchQueueScheduler(queue: sendingQueue, internalSerialQueueName: sendingQueue.label))
            .flatMap { [unowned self] _ -> Observable<Void> in
                let model = GroupInfoReq()
                model.groupId = id
                
                var error: NSError?
                self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: .info, messageId: -1, message: model.data(), error: &error)
                guard error == nil else {
                    return .error(GroupInfoError.wrongData)
                }
                return .just(())
            }
            .flatMapLatest { [unowned self] in
                self.messageReceiver.didReceiveGroupInfo
            }
            .filter { $0.groupId == id }
            .observeOn(MainScheduler.instance)
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .take(1)
    }
    
    func join(group shareId: String) -> Observable<Int64> {
        guard let friendNumber = try? self.database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: self.tokManager.tox) else {
            return .error(GroupInfoError.wrongData)
        }
        guard tokManager.tox.shareIdIsValid(shareId) else {
            return .error(GroupInfoError.wrongShareId)
        }
        guard let groupNumber = shareId.matchGroupNumber() else {
            return .error(GroupInfoError.wrongShareId)
        }
        
        return Observable.just((), scheduler: SerialDispatchQueueScheduler(queue: sendingQueue, internalSerialQueueName: sendingQueue.label))
            .flatMap { [unowned self] _ -> Observable<Void> in
                let model = GroupInviteReq()
                model.groupId = UInt64(groupNumber)
                model.inviteePk = self.tokManager.tox.publicKey.data(using: .utf8)
                
                var error: NSError?
                self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: OCTToxGroupCmd.invite, messageId: -1, message: model.data(), error: &error)
                guard error == nil else {
                    return .error(GroupInfoError.wrongData)
                }
                return .just(())
            }
            .flatMapLatest { [unowned self] in
                return self.messageReceiver.joinedGroup
            }
        .delay(.seconds(1), scheduler: MainScheduler.instance)
        .observeOn(MainScheduler.instance)
        .timeout(.seconds(20), scheduler: MainScheduler.instance)
        .take(1)
    }
    
    func getPeerList(groupId: UInt64, page: UInt32) -> Observable<([Peer], Bool)> {
        guard let friendNumber = try? self.database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: self.tokManager.tox) else {
            return .error(GroupInfoError.wrongData)
        }
        
        return Observable.just((), scheduler: SerialDispatchQueueScheduler(queue: sendingQueue, internalSerialQueueName: sendingQueue.label))
            .flatMap { _ -> Observable<Void> in
                let model = GroupPeerListNewReq()
                model.groupId = groupId
                model.page = page
                let data = model.data()
                
                var error: NSError?
                self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: OCTToxGroupCmd.peerList, messageId: -1, message: data, error: &error)
                
                guard error == nil else {
                    return .error(GroupInfoError.wrongData)
                }
                return .just(())
            }
            .observeOn(MainScheduler.instance)
            .flatMap { [unowned self] in
                return self.tokManager.rx.groupMessageReceived()
            }
            .observeOn(SerialDispatchQueueScheduler(qos: .default))
            .filterMap { [unowned self] args -> FilterMap<([Peer], Bool)> in
                let (groupCmd, data) = args
                guard groupCmd == OCTToxGroupCmd.peerListResponse else {
                    return .ignore
                }
                guard let model = try? GroupPeerListNewRes(data: data), model.groupId == groupId else {
                    return .ignore
                }
                guard let peers = model.groupPeerArray as? [GroupPeer] else {
                    return .ignore
                }
                let list = peers.map { model -> Peer in
                    let name = String(data: model.peerName, encoding: .utf8)
                    let publicKey = OCTTox.bin(toHexString: model.peerPk) ?? "?"
                    
                    let isMe = publicKey == self.tokManager.tox.publicKey
                    let nickname = (isMe ? self.tokManager.tox.userName() : name) ?? "Tok"
                    
                    let image: UIImage = AvatarManager.shared.image(bySenderId: publicKey, messageService: self)
                    return Peer(nickname: nickname, publicKey: publicKey, confirmFlag: model.confirmFlag, avatar: image)
                }
                
                let theEnd = model.end == 1
                return .map((list, theEnd))
            }
            .observeOn(MainScheduler.instance)
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .take(1)
    }
    
    func getRecommendGroupList(page: UInt32) -> Observable<([GroupRecommendInfo], Bool)> {
        guard let friendNumber = try? self.database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: self.tokManager.tox) else {
            return .error(GroupInfoError.wrongData)
        }
        
        return Observable.just((), scheduler: SerialDispatchQueueScheduler(queue: sendingQueue, internalSerialQueueName: sendingQueue.label))
            .flatMap { [unowned self] _ -> Observable<Void> in
                let model = GroupRecommendRequest()
                model.page = page
                let data = model.data()
                
                var error: NSError?
                self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: .recommend, messageId: -1, message: data, error: &error)
                
                guard error == nil else {
                    return .error(GroupInfoError.wrongData)
                }
                return .just(())
            }
            .observeOn(MainScheduler.instance)
            .flatMap { [unowned self] in
                return self.tokManager.rx.groupMessageReceived()
            }
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .filterMap { args -> FilterMap<([GroupRecommendInfo], Bool)> in
                let (groupCmd, data) = args
                guard groupCmd == OCTToxGroupCmd.recommendResponse else {
                    return .ignore
                }
                guard let model = try? GroupRecommendResponse(data: data) else {
                    return .ignore
                }
                guard let list = model.infoArray as? [GroupRecommendInfo] else {
                    return .ignore
                }
                let theEnd = model.end == 1
                return .map((list, theEnd))
            }
            .observeOn(MainScheduler.instance)
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .take(1)
    }
    
    func pullGroupMessagesIfNeeded(chatId: String, startTimeInterval: TimeInterval, endTimeInterval: TimeInterval, up: Bool, tail: Bool, pageSize: Int = 30) {
        sendingQueue.async { [weak self] in
            self?.messageReceiver.pullGroupMessagesIfNeeded(chatId: chatId, startTimeInterval: startTimeInterval, endTimeInterval: endTimeInterval, up: up, tail: tail, pageSize: pageSize)
        }
    }

    func invite(friendPublicKey: String, groupNumber: Int) {
        sendingQueue.async {
            guard let friendNumber = try? self.database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: self.tokManager.tox) else {
                return
            }
            
            let model = GroupInviteReq()
            model.groupId = UInt64(groupNumber)
            model.inviterPk = self.tokManager.tox.publicKey.data(using: .utf8)
            model.inviteePk = friendPublicKey.data(using: .utf8)
            
            self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: .invite, messageId: -1, message: model.data(), error: nil)
        }
    }
}

extension MessageService {
    func pullNodes() {
        sendingQueue.async {
            guard let friendNumber = try? self.database.friendNumber(publicKey: BotService.shared.groupBot.publicKey, tox: self.tokManager.tox) else {
                return
            }
            
            let model = NodesFileRequest()
            let data = try? Data(contentsOf: ToxNodes.filePath())
            model.hash_p = self.tokManager.tox.hashData(data)
            self.tokManager.tox.sendGroupMessage(withBotFriendNumber: friendNumber, groupCmd: .nodesFilePullRequest, messageId: -1, message: model.data(), error: nil)
        }
    }
}

extension MessageService {
    func sendVersionInfoRequest() -> Observable<VersionInfo> {
        return Observable.deferred {
            guard let friend = self.database.findFriend(withPublicKey: BotService.shared.offlineBot.publicKey),
                friend.isConnected else {
                    return Observable.error(NSError(domain: "com.insight.api.error", code: -1, userInfo: nil))
            }
            let tokManager = self.tokManager
            guard let friendNumber = try? self.database.friendNumber(publicKey: BotService.shared.offlineBot.publicKey, tox: tokManager.tox) else {
                return Observable.error(NSError(domain: "com.insight.api.error", code: -1, userInfo: nil))
            }
            
            let messageId = tokManager.tox.generateMessageId()
            let model = VersionInfoReq()
            
            tokManager.tox.sendOfflineMessage(withBotFriendNumber: friendNumber, offlineCmd: .versionInfoRequest, messageId: messageId, message: model.data(), error: nil)
            
            return tokManager.rx.offlineMessageReceived()
                .subscribeOn(SerialDispatchQueueScheduler(internalSerialQueueName: "com.insight.offline.message.process"))
                .filterMap { (friendNumber, offlineCmd, data) -> FilterMap<VersionInfo> in
                    guard offlineCmd == .versionInfoResponse else {
                        return .ignore
                    }
                    guard let model = try? VersionInfoRes(data: data) else {
                        return .ignore
                    }
                    let info = VersionInfo(pb: model)
                    return .map(info)
            }
            .observeOn(MainScheduler.instance)
            .timeout(.seconds(15), scheduler: MainScheduler.instance)
        }
    }
}
