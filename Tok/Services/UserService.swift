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
            guard let manager = toxMananger else {
                return
            }
            
            setupBots(manager: manager)
            uploadPushManager.manager = manager
        }
    }
    
    lazy var uploadPushManager = UploadPushManager()
    
    fileprivate var messagesToken: RLMNotificationToken?
    
    static let shared = UserService()
    
    lazy var dhtBlock: ((OCTTox) -> [[String: Any]]) = { [weak self] tox in
        guard let self = self else { return [] }
        return self.dhtArray(tox: tox)
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
    
    func tryLogin() -> Observable<(OCTManager, TokManager)?> {
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
            let tokManager = TokManager(profileName: profileName)
            ToxFactory.createToxWithConfiguration(configuration,
                                                  encryptPassword: password,
                                                  dhtArrayBlock: self.dhtBlock,
                                                  delegate: tokManager,
                                                  successBlock: { manager in
                                                    tokManager.toxManager = manager
                                                    self.toxMananger = manager
                                                    self.bootstrap()
                                                    
                                                    observer.onNext((manager, tokManager))
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
    
    func register(profile: String, password: String) -> Observable<(OCTManager, TokManager)> {
        return Observable.create { observer -> Disposable in
            let path = ProfileManager().pathForProfileWithName(profile)
            guard let configuration = OCTManagerConfiguration.configurationWithBaseDirectory(path, profileName: profile) else {
                observer.onError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Profile does not exist", comment: "")]))
                return Disposables.create()
            }
            
            let tokManager = TokManager(profileName: profile)
            ToxFactory.createToxWithConfiguration(configuration,
                                                  encryptPassword: password,
                                                  dhtArrayBlock: self.dhtBlock,
                                                  delegate: tokManager,
                                                  successBlock: { [weak self] manager -> Void in
                tokManager.toxManager = manager
                self?.toxMananger = manager
                self?.bootstrap()
                
                KeychainManager().toxPasswordForActiveAccount = password
                let userDefaults = UserDefaultsManager()
                userDefaults.lastActiveProfile = profile
                
                observer.onNext((manager, tokManager))
                observer.onCompleted()
                }, failureBlock: { error -> Void in
                    observer.onError(error)
            })
            
            return Disposables.create()
            }
    }
    
    func login(profile: String, password: String) -> Observable<Void> {
        return register(profile: profile, password: password)
            .do(onNext: { [weak self] (manager, _) in
                self?.didLogin.onNext(())
            })
            .map { _ in () }
    }
    
    public func bootstrap() {
        guard let manager = toxMananger else {
            return
        }
        
        // Use custom bootstrap nodes
        if UserDefaultsManager().customBootstrapEnabled {
            NodeModel.retrieve().forEach { node in
                switch node.networkProtocol {
                case .UDP:
                    let port = OCTToxPort(node.port)
                    manager.bootstrap.addNode(withIpv4Host: node.server, ipv6Host: nil, udpPort: port, tcpPorts: [], publicKey: node.publicKey)
                case .TCP:
                    manager.bootstrap.addNode(withIpv4Host: node.server, ipv6Host: nil, udpPort: 0, tcpPorts: [NSNumber(value: node.port)], publicKey: node.publicKey)
                }
            }
        }
        ToxNodes.retrieve().nodes.forEach { node in
            var tcpPorts: [NSNumber] = []
            if let ports = node.tcpPorts {
                tcpPorts = ports.map { NSNumber(value: $0) }
            }
            
            manager.bootstrap.addNode(withIpv4Host: node.ipv4, ipv6Host: node.ipv6, udpPort: OCTToxPort(node.port), tcpPorts: tcpPorts, publicKey: node.publicKey)
        }
        manager.bootstrap.addPredefinedNodes()
        manager.bootstrap.bootstrap(withDHTRelay: [])
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
        uploadPushManager.resetPushToken()
        toxMananger?.managerGetTox()?.stop()
        toxMananger = nil
        KeychainManager().deleteActiveAccountData()
        
        didLogout.onNext(())
    }
    
    func setupBots(manager: OCTManager) {
        manager.offlineBotPublicKey = BotService.shared.offlineBot.publicKey
        manager.groupBotPublicKey = BotService.shared.groupBot.publicKey
        manager.strangerBotPublicKey = BotService.shared.findFriendBot.publicKey
    }
    
    func deleteProfile(withLogout: Bool = true) throws {
        let userDefaults = UserDefaultsManager()
        let profileManager = ProfileManager()
        
        let name = userDefaults.lastActiveProfile!
        
        try profileManager.deleteProfileWithName(name)
        userDefaults.lastActiveProfile = nil
        
        if withLogout {
            logout()
        }
    }
    
    private func dhtArray(tox: OCTTox) -> [[String : Any]] {
        BotService.shared.initServerList(tox: tox)
        guard let groupBot = BotService.shared.groupBot else {
            return []
        }
        let array: [[String : Any]] = [
            ["friendNumber": groupBot.friendNumber,
             "dhtPublicKey": groupBot.dhtPublicKey,
             "host": groupBot.host,
             "port": groupBot.port]
        ]
        return array
    }
}
