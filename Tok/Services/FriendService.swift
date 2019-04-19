//
//  FriendService.swift
//  Tok
//
//  Created by Bryce on 2019/4/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import RxSwift

struct FriendService {
    
    enum SendRequestError: Error {
        case wrongID
        case added
        case yourID
    }
    
    static func sendRequest(address: String, message: String) -> Observable<Void> {
        return Observable.deferred {
            guard let result = address.matchAddressString() else {
                return .error(SendRequestError.wrongID)
            }
            
            let pk = (result as NSString).substring(to: Int(kOCTToxPublicKeyLength))
            guard UserService.shared.toxMananger!.friends.friend(withPublicKey: pk) == nil else {
                return Observable.error(SendRequestError.added)
            }
            
            guard result != UserService.shared.toxMananger!.user.userAddress.uppercased() else {
                return Observable.error(SendRequestError.yourID)
            }
            
            let botService = BotService()
            let userDefaultsManager = UserDefaultsManager()
            if pk == botService.findFriendBot.publicKey {
                userDefaultsManager.showFindFriendBotTip = false
            } else if pk == botService.offlineMessageBot.publicKey {
                userDefaultsManager.showOfflineMessageBotTip = false
            }
            
            do {
                try UserService.shared.toxMananger!.friends.sendFriendRequest(toAddress: result, message: message)
                return .just(())
            } catch let error {
                return Observable.error(error)
            }
        }
    }
}

extension FriendService.SendRequestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .wrongID:
            return NSLocalizedString("Wrong ID. It should contain Tok ID", comment: "")
        case .added:
            return NSLocalizedString("You're already friends", comment: "")
        case .yourID:
            return NSLocalizedString("This is your Tok ID", comment: "")
        }
    }
}
