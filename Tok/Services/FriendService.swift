//
//  FriendService.swift
//  Tok
//
//  Created by Bryce on 2019/4/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import RxSwift

struct FriendService {
    
    let toxManager: OCTManager
    let database: Database
    init(toxManager: OCTManager, database: Database) {
        self.toxManager = toxManager
        self.database = database
    }
    
    enum SendRequestError: Error {
        case wrongID
        case added
        case yourID
        case botID
        case sendError
    }
    
    @discardableResult
    func sendFriendRequest(address: String, message: String, alias: String? = nil) -> Result<Bool, SendRequestError> {
        guard let result = address.matchAddressString() else {
            return .failure(SendRequestError.wrongID)
        }
        
        let pk = (result as NSString).substring(to: Int(kOCTToxPublicKeyLength))
        guard self.database.findFriend(withPublicKey: pk) == nil else {
            return .failure(SendRequestError.added)
        }
        guard result != self.toxManager.user.userAddress else {
            return .failure(SendRequestError.yourID)
        }
        do {
            try self.toxManager.friends.sendFriendRequest(toAddress: result, message: message, alias: alias)
            self.sendOfflineFriendRequest(publicKey: pk, message: message)
            return .success(true)
        } catch {
            return .failure(SendRequestError.sendError)
        }
    }
    
    private func sendOfflineFriendRequest(publicKey: String, message: String) {
        guard let offlineBot = database.findFriend(withPublicKey: BotService.shared.offlineBot.publicKey),
            offlineBot.isConnected else {
            return
        }
        
        let messageId = toxManager.managerGetTox().generateMessageId()
        let messageData = message.data(using: .utf8)
        
        let model = OfflineMessageReq()
        model.localMsgId = messageId
        model.toPk = publicKey.data(using: .utf8)
        model.cryptoMessage = messageData
        model.msgType = 2
        
        toxManager.managerGetTox()?.sendOfflineMessage(withBotFriendNumber: offlineBot.friendNumber, offlineCmd: .send, messageId: messageId, message: model.data(), error: nil)
    }
}

extension FriendService.SendRequestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .wrongID, .botID:
            return NSLocalizedString("Wrong ID. It should contain Tok ID", comment: "")
        case .added:
            return NSLocalizedString("You're already friends", comment: "")
        case .yourID:
            return NSLocalizedString("This is your Tok ID", comment: "")
        case .sendError:
            return NSLocalizedString("Something went wrong and try again later", comment: "")
        }
    }
}

fileprivate extension FriendService {
    func addFriendRequest(message: String, publicKey: String, isOutgoing: Bool) {
        let friendRequest = database.findFriendRequest(withPublicKey: publicKey)
        guard friendRequest == nil else {
            return
        }
        
        let friend = database.findFriend(withPublicKey: publicKey)
        guard friend == nil else {
            return
        }
        
        let request = OCTFriendRequest()
        request.publicKey = publicKey
        request.message = message
        request.dateInterval = Date().timeIntervalSince1970
        request.isOutgoing = isOutgoing
        
        database.add(object: request)
    }

    func createFriend(friendNumber: OCTToxFriendNumber, alias: String?, friendState: Int) throws -> OCTFriend {
        let tox = toxManager.managerGetTox()!
        
        let friend = OCTFriend()
        friend.friendNumber = friendNumber
        friend.publicKey = try tox.publicKey(fromFriendNumber: friendNumber)
        friend.name = try tox.friendName(withFriendNumber: friendNumber)
        friend.statusMessage = try tox.friendStatusMessage(withFriendNumber: friendNumber)
        var error: NSError?
        friend.connectionStatus = tox.friendConnectionStatus(withFriendNumber: friendNumber, error: &error)
        if let error = error {
            throw error
        }
        friend.isConnected = friend.connectionStatus != .none
        if let alias = alias {
            friend.nickname = alias
        } else {
            friend.nickname = friend.name ?? String(friend.publicKey.prefix(8))
        }
        database.add(object: friend)
        return friend
    }
}
