//
//  BotService.swift
//  Tok
//
//  Created by Bryce on 2019/3/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import RxSwift
import UIKit

struct BotService {
    
    enum Command: String {
        case start = "/start"
        case set = "/set"
    }
    
    var publicKey: String {
        return UserDefaults.standard.botPublicKey
    }
    
    private(set) var address: String {
        get {
            return UserDefaults.standard.botAddress
        }
        set {
            UserDefaults.standard.botAddress = newValue
        }
    }
    
    fileprivate var friendToken: RLMNotificationToken?
    
    lazy var bot: OCTFriend = {
        return getBot() ?? defaultBot
    }()
    
    lazy var beAdded: Bool = {
        return getBot() != nil
    }()
    
    private lazy var defaultBot: OCTFriend = {
        let friend = OCTFriend()
        friend.nickname = NSLocalizedString("FindFriendBot", comment: "")
        friend.publicKey = UserDefaults.standard.botPublicKey
        friend.statusMessage = NSLocalizedString("What can I do? FindFriendBot can help you find more friends. Click or Type /help for a list of commands.", comment: "")
        friend.avatarData = UIImage(named: "BotPlaceholder")?.pngData()
        return friend
    }()
    
    private func getBot() -> OCTFriend? {
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        let results = UserService.shared.toxMananger!.objects.friends(predicate: predicate)
        return results.firstObject
    }
}

extension UserDefaults {
    
    var botAddress: String {
        get {
            return string(forKey: "FindFriendBotAddressKey") ?? "3415845A7145854DE91046FF4666503A83EED05BC47CA222644C5F47A8E0F072938433360B34"
        }
        set {
            set(newValue, forKey: "FindFriendBotAddressKey")
        }
    }
    
    var botPublicKey: String {
        return String(botAddress.prefix(64))
    }
}
