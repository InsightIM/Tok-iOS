//
//  UserService.swift
//  Tok
//
//  Created by Bryce on 2018/6/19.
//  Copyright © 2018 Insight. All rights reserved.
//

import Foundation
import RxSwift

class UserService {
    
    let didLogin = PublishSubject<Void>()
    let didLogout = PublishSubject<Void>()
    
    fileprivate(set) var toxMananger: OCTManager? = nil {
        didSet {
            setupAutodownload()
        }
    }
    
    fileprivate var messagesToken: RLMNotificationToken?
    
    static let shared = UserService()
    
    private let avatarManager = AvatarManager()
    var avatarImage: UIImage? {
        guard let toxMananger = toxMananger else {
            return nil
        }
        
        var image: UIImage?
        if let data = toxMananger.user.userAvatar() {
            image = UIImage(data: data)
        }
        return image ?? avatarManager.avatarFromString("?", diameter: 36)
    }
    
    var avatarData: Data? {
        guard let toxMananger = toxMananger else {
            return nil
        }
        
        return toxMananger.user.userAvatar()
    }
    
    var nickName: String? {
        guard let toxMananger = toxMananger else {
            return nil
        }
        return toxMananger.user.userName()
    }
    
    var statusMessage: String? {
        guard let toxMananger = toxMananger else {
            return nil
        }
        
        let message = toxMananger.user.userStatusMessage()
        if message == nil {
            let defaultMessage = NSLocalizedString("Hey there! I'm using Tok.", comment: "")
            try? toxMananger.user.setUserStatusMessage(defaultMessage)
            return defaultMessage
        }
        return message
    }
    
    var currentUserStatus: UserStatus {
        guard let toxMananger = toxMananger else {
            return .offline
        }
        return UserStatus(connectionStatus: toxMananger.user.connectionStatus, userStatus: toxMananger.user.userStatus)
    }
    
    func createProfile(_ profileName: String, copyFromURL: URL?, password: String?) -> Bool {
        if profileName.isEmpty {
            return false
        }
        
        let profileManager = ProfileManager()
        
        do {
            try profileManager.createProfileWithName(profileName, copyFromURL: copyFromURL)
        }
        catch {
            return false
        }
        
        return true
    }
    
    func tryLogin() -> Observable<OCTManager?> {
        guard let password = KeychainManager().toxPasswordForActiveAccount else {
            return Observable.just(nil)
        }
        
        let deleteActiveAccountAndRetry: () -> Void = {
            KeychainManager().deleteActiveAccountData()
        }
        
        guard let profileName = UserDefaultsManager().lastActiveProfile else {
            deleteActiveAccountAndRetry()
            return Observable.just(nil)
        }
        
        let path = ProfileManager().pathForProfileWithName(profileName)
        
        guard let configuration = OCTManagerConfiguration.configurationWithBaseDirectory(path, profileName: profileName) else {
            deleteActiveAccountAndRetry()
            return Observable.just(nil)
        }
        
        return Observable.create { observer -> Disposable in
            ToxFactory.createToxWithConfiguration(configuration,
                                                  encryptPassword: password,
                                                  successBlock: { manager in
                                                    self.toxMananger = manager
                                                    self.toxMananger?.bootstrap.addPredefinedNodes()
                                                    self.toxMananger?.bootstrap.bootstrap()
                                                    observer.onNext(manager)
                                                    observer.onCompleted()
            },
                                                  failureBlock: { _ in
                                                    deleteActiveAccountAndRetry()
                                                    observer.onNext(nil)
                                                    observer.onCompleted()
            })
            
            return Disposables.create()
        }
    }
    
    func login(profile: String, nickname: String? = nil, password: String) -> Observable<Void> {
        return Observable.create { observer -> Disposable in
            let path = ProfileManager().pathForProfileWithName(profile)
            guard let configuration = OCTManagerConfiguration.configurationWithBaseDirectory(path, profileName: profile) else {
                observer.onError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Profile does not exist", comment: "")]))
                return Disposables.create()
            }
            
            ToxFactory.createToxWithConfiguration(configuration, encryptPassword: password, successBlock: { [weak self] manager -> Void in
                if let nickname = nickname {
                    _ = try? manager.user.setUserName(nickname)
                }
                
                self?.toxMananger = manager
                self?.toxMananger?.bootstrap.addPredefinedNodes()
                self?.toxMananger?.bootstrap.bootstrap()
                
                KeychainManager().toxPasswordForActiveAccount = password
                let userDefaults = UserDefaultsManager()
                userDefaults.lastActiveProfile = profile
                
                observer.onNext(())
                observer.onCompleted()
                }, failureBlock: { error -> Void in
                    observer.onError(error)
            })
            
            return Disposables.create()
            }
            .do(onNext: { [weak self] _ in
                self?.didLogin.onNext(())
            })
    }
    
    private func isProfileEncrypted(_ profile: String) -> Bool {
        let profilePath = ProfileManager().pathForProfileWithName(profile)
        
        let configuration = OCTManagerConfiguration.configurationWithBaseDirectory(profilePath, profileName: profile)!
        let dataPath = configuration.fileStorage.pathForToxSaveFile
        
        guard FileManager.default.fileExists(atPath: dataPath) else {
            return false
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: dataPath)) else {
            return false
        }
        
        return OCTToxEncryptSave.isDataEncrypted(data)
    }
    
    func logout() {
        toxMananger = nil
        KeychainManager().deleteActiveAccountData()
        
        didLogout.onNext(())
    }
    
    func matchNewFriendCommand(text: String) -> String? {
        guard let toxMananger = toxMananger else {
            return nil
        }
        guard let address = text.matchCommandString() else {
            return nil
        }
        // it's not your public key
        guard address != toxMananger.user.userAddress.uppercased() else {
            return nil
        }
        // it's not friend public key
        let pk = (address as NSString).substring(to: Int(kOCTToxPublicKeyLength))
        guard toxMananger.friends.friend(withPublicKey: pk) == nil else {
            return nil
        }
        return address
    }
    
    func setupAutodownload() {
        guard let toxMananger = toxMananger, UserDefaultsManager().autodownloadFiles else {
            messagesToken?.invalidate()
            return
        }
        
        let messages = toxMananger.objects.messages()
        messagesToken = messages.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let messages, _, let insertions, _):
                guard let messages = messages else {
                    break
                }
                insertions.forEach { index in
                    let message = messages[index]
                    self.toxMananger?.files.acceptFileTransfer(message)
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
