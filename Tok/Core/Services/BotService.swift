//
//  BotService.shared.swift
//  Tok
//
//  Created by Bryce on 2019/7/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class BotService {
    
    struct ServiceList: Decodable {
        var groups: [Bot]
        var offlines: [Bot]
        var findFriends: [Bot]
        var files: [Bot]
        
        enum CodingKeys: String, CodingKey {
            case groups
            case offlines
            case findFriends
            case files
        }
    }
    
    struct Bot: Decodable, Hashable {
        enum BotType: Int, Decodable {
            case group = 0
            case offline = 1
            case findFriend = 2
            case file = 3
        }
        
        var type: BotType
        var address: String
        var dhtPublicKey: String
        var host: String
        var port: UInt
        var publicKey: String {
            return String(address.prefix(Int(kOCTToxPublicKeyLength)))
        }
        
        var friendNumber: OCTToxFriendNumber = 0
        
        func change(friendNumber: OCTToxFriendNumber) -> Bot {
            return Bot(type: type,
                       address: address,
                       dhtPublicKey: dhtPublicKey,
                       host: host,
                       port: port,
                       friendNumber: friendNumber)
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case address
            case dhtPublicKey
            case host
            case port
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(publicKey.hashValue)
        }

        static func == (lhs: Bot, rhs: Bot) -> Bool {
            return lhs.publicKey == rhs.publicKey
        }
    }
    
    static let shared = BotService()
    
    private(set) var groupBot: Bot!
    private(set) var offlineBot: Bot!
    private(set) var findFriendBot: Bot!
    private(set) var fileBot: Bot!
    
    func initServerList(tox: OCTTox) {
        if let url = Bundle.main.url(forResource: "ServerList", withExtension: "plist"),
            let data = try? Data(contentsOf: url) {
            let decoder = PropertyListDecoder()
            do {
                let serverList = try decoder.decode(ServiceList.self, from: data)
                
                groupBot = try findBot(tox: tox, bots: serverList.groups)
                offlineBot = try findBot(tox: tox, bots: serverList.offlines)
                findFriendBot = try findBot(tox: tox, bots: serverList.findFriends)
                fileBot = try findBot(tox: tox, bots: serverList.files)
            } catch {
                fatalError("load server list error")
            }
        }
    }
    
    enum FindServerError: Error {
        case notFound
    }
    
    private func findBot(tox: OCTTox, bots: [Bot]) throws -> Bot {
        let bot = bots.compactMap { bot -> Bot? in
            guard let friendNumber = findFriendNumber(tox: tox, publicKey: bot.publicKey) else {
                return nil
            }
            return bot.change(friendNumber: friendNumber)
        }.first ?? addBotAsFriend(bot: bots.randomElement(), tox: tox)
        
        guard let server = bot else {
            throw FindServerError.notFound
        }
        return server
    }
    
    private func findFriendNumber(tox: OCTTox, publicKey: String) -> OCTToxFriendNumber? {
        var error: NSError?
        let friendNumber = tox.friendNumber(withPublicKey: publicKey, error: &error)
        if error == nil, friendNumber != kOCTToxFriendNumberFailure {
            return friendNumber
        }
        return nil
    }
    
    private func addBotAsFriend(bot: Bot?, tox: OCTTox) -> Bot? {
        guard let bot = bot else {
            return nil
        }
        var error: NSError?
        let friendNumber = tox.addFriend(withAddress: bot.address, message: "add bot", error: &error)
        return error == nil
            ? bot.change(friendNumber: friendNumber)
            : nil
    }
}
