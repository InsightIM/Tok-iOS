//
//  NameManager.swift
//  Tok
//
//  Created by Bryce on 2019/6/27.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class NameManager {
    fileprivate let cache: NSCache<NSString, NSString>
    private let database: Database
    init(database: Database) {
        self.database = database
        self.cache = NSCache()
    }
    
    func name(by senderId: String) -> String {
        if let cacheName = cache.object(forKey: senderId as NSString) as String? {
            return cacheName
        }
        
        let defaultName = "Tok User"
        if let friend = database.findFriend(withPublicKey: senderId) {
            cache.setObject(friend.nickname as NSString, forKey: senderId as NSString)
            return friend.nickname
        }
        
        if let peer = database.findPeer(withPublicKey: senderId) {
            let name = peer.nickname ?? defaultName
            cache.setObject(name as NSString, forKey: senderId as NSString)
            return name
        }
        
        cache.setObject(defaultName as NSString, forKey: senderId as NSString)
        return defaultName
    }
}
