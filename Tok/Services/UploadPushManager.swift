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
    private let offlineBot = OfflineBotModel()
    
    var deviceToken: Data?
    
    static let shared = UploadPushManager()
    
    deinit {
        friendToken?.invalidate()
    }
    
    func uploadPushTokenIfNeeded() {
        guard friendToken == nil else { return }
        let publicKey = offlineBot.publicKey
        let predicate = NSPredicate(format: "publicKey == %@", publicKey)
        let results = UserService.shared.toxMananger!.objects.friends(predicate: predicate)
        addNotification(results: results)
    }
    
    private func addNotification(results: Results<OCTFriend>) {
        friendToken = results.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                fallthrough
            case .update:
                print("Offline Bot update")
                self.uploadDeviceToken()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func uploadDeviceToken() {
        if let tox = UserService.shared.toxMananger, offlineBot.getBot()?.isConnected == true, let token = deviceToken {
            tox.chats.uploadPushToken(token.hexEncodedString())
            print("Upload Push token：\(token.hexEncodedString())")
            deviceToken = nil
        }
    }
}
