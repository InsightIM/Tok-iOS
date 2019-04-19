//
//  BotModel.swift
//  Tok
//
//  Created by Bryce on 2019/4/19.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

protocol BotModelProtocol {
    var publicKey: String { get }
    var address: String { get }
    var beAdded: Bool { get }
    var defaultBot: OCTFriend { get }
    func getBot() -> OCTFriend?
}

extension BotModelProtocol {
    var beAdded: Bool {
        return getBot() != nil
    }
    
    func getBot() -> OCTFriend? {
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        let results = UserService.shared.toxMananger!.objects.friends(predicate: predicate)
        return results.firstObject
    }
}

struct FindFriendBotModel: BotModelProtocol {
    
    enum Command: String {
        case start = "/start"
        case set = "/set"
    }
    
    var publicKey: String {
        return UserDefaults.standard.findFriendBotPublicKey
    }
    
    private(set) var address: String {
        get {
            return UserDefaults.standard.findFriendBotAddress
        }
        set {
            UserDefaults.standard.findFriendBotAddress = newValue
        }
    }
    
    var defaultBot: OCTFriend = {
        let friend = OCTFriend()
        friend.nickname = NSLocalizedString("FindFriendBot", comment: "")
        friend.publicKey = UserDefaults.standard.findFriendBotPublicKey
        friend.statusMessage = NSLocalizedString("What can I do? FindFriendBot can help you find more friends. Click or Type /help for a list of commands.", comment: "")
        friend.avatarData = UIImage(named: "BotPlaceholder")?.pngData()
        return friend
    }()
}

struct OfflineBotModel: BotModelProtocol {
    
    var publicKey: String {
        return UserDefaults.standard.offlineBotPublicKey
    }
    
    private(set) var address: String {
        get {
            return UserDefaults.standard.offlineBotAddress
        }
        set {
            UserDefaults.standard.offlineBotAddress = newValue
        }
    }
    
    var defaultBot: OCTFriend = {
        let friend = OCTFriend()
        friend.nickname = NSLocalizedString("OfflineMessageBot", comment: "")
        friend.publicKey = UserDefaults.standard.offlineBotPublicKey
        friend.statusMessage = NSLocalizedString("This bot is a temporary solution designed to send offline messages in Tok, and it works only when both side of the conversation add this bot.", comment: "")
        friend.avatarData = UIImage(named: "BotPlaceholder")?.pngData()
        return friend
    }()
}

fileprivate extension UserDefaults {
    
    var findFriendBotAddress: String {
        get {
            return string(forKey: "FindFriendBotAddressKey") ?? "3415845A7145854DE91046FF4666503A83EED05BC47CA222644C5F47A8E0F072938433360B34"
        }
        set {
            set(newValue, forKey: "FindFriendBotAddressKey")
        }
    }
    
    var findFriendBotPublicKey: String {
        return String(findFriendBotAddress.prefix(64))
    }
    
    var offlineBotAddress: String {
        get {
            return string(forKey: "OfflineBotAddressKey") ?? "3415845A7145854DE91046FF4666503A83EED05BC47CA222644C5F47A8E0F072938433360B34"
        }
        set {
            set(newValue, forKey: "OfflineBotAddressKey")
        }
    }
    
    var offlineBotPublicKey: String {
        return String(offlineBotAddress.prefix(64))
    }
}
