//
//  UploadPushManager.swift
//  Tok
//
//  Created by Bryce on 2019/4/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class UploadPushManager {
    fileprivate var friendToken: RLMNotificationToken?
    
    var deviceToken: Data?
    var manager: OCTManager?
    
    init() {
        addNotification()
    }
    
    deinit {
        friendToken?.invalidate()
    }
    
    func uploadPushTokenIfNeeded() {
        guard let manager = manager else {
            return
        }
        guard let offlineBot = getOfflineBot(), offlineBot.isConnected, let token = deviceToken else {
            return
        }
        deviceToken = nil
        
        print("Upload Push token：\(token.hexEncodedString())")
        manager.chats.uploadPushToken(token.hexEncodedString())
    }
    
    func resetPushToken() {
        if let offlineBot = getOfflineBot(), offlineBot.isConnected {
            manager?.chats.uploadPushToken("")
            print("Reset Push token")
        }
    }
    
    private func getOfflineBot() -> OCTFriend? {
        return manager?.friends.friend(withPublicKeyIgnoreState: BotService.shared.offlineBot.publicKey)
    }
    
    private func addNotification() {
        guard friendToken == nil, let realmManager = manager?.managerGetRealmManager() else { return }
        let publicKey = BotService.shared.offlineBot.publicKey
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        guard let results = realmManager.objects(with: OCTFriend.self, predicate: predicate, db: realmManager.database()) else {
            return
        }
        
        let friends = Results<OCTFriend>(results: results)
        friendToken = friends.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update:
                self.uploadPushTokenIfNeeded()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
