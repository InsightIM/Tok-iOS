//
//  FindFriendService.swift
//  Tok
//
//  Created by Bryce on 2019/7/2.
//  Copyright © 2019 Insight. All rights reserved.
//

import RxSwift

class FindFriendService {
    lazy var bot: OCTFriend? = {
        return toxManager.managerGetRealmManager()?.friend(withPublicKey: BotService.shared.findFriendBot.publicKey)
    }()
    
    var bio: String? {
        get {
            let string = UserDefaults.standard.string(forKey: "\(toxManager.user.publicKey)_UserFindStrangerBio")
            if let string = string, string.isNotEmpty {
              return string
            }
            return NSLocalizedString("DefaultFindStrangerBio", comment: "")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "\(toxManager.user.publicKey)_UserFindStrangerBio")
        }
    }
    
    var isAnonymous: Bool = !UserDefaultsManager().startFindStranger {
        didSet {
            guard oldValue != isAnonymous else {
                return
            }
            UserDefaultsManager().startFindStranger = !isAnonymous
        }
    }
    
    fileprivate var friendToken: RLMNotificationToken?
    private let botOnline = PublishSubject<Bool>()
    
    let messageService: MessageService
    private let toxManager: OCTManager
    init(messageService: MessageService) {
        self.messageService = messageService
        self.toxManager = messageService.tokManager.toxManager
        addFriendNotification()
    }
    
    deinit {
        friendToken?.invalidate()
    }
    
    func sendStart() {
        isAnonymous = false
        let message = "/start \(toxManager.user.userAddress)"
        toxManager.chats.sendStrangerCommandMessage(message)
        
        let set = "/set \(bio ?? NSLocalizedString("DefaultFindStrangerBio", comment: ""))"
        toxManager.chats.sendStrangerCommandMessage(set)
    }
    
    func sendStop() {
        isAnonymous = true
        let message = "/stop"
        toxManager.chats.sendStrangerCommandMessage(message)
    }

    func getAvatar(pk: String) -> Observable<UIImage?> {
        return Observable.deferred {
            guard let bot = self.bot else {
                return .error(NSError())
            }
            
            if let image = self.cacheAvatarImage(pk: pk) {
                return .just(image)
            }
            
            let startObservable = bot.isConnected ? Observable.just(()) : self.botOnline.distinctUntilChanged().map { _ in () }
            return startObservable
                .flatMapLatest { _ -> Observable<Notification> in
                    let model = StrangerGetAvatartReq()
                    model.pk = pk.data(using: .utf8)
                    print("😺Get Avatar: \(pk)");
                    self.toxManager.chats.sendStrangerMessage(model.data(), command: OCTToxStrangerCmd.getAvatar, botFriendNumber: bot.friendNumber)
                    return NotificationCenter.default.rx.notification(Notification.Name(rawValue: kOCTStrangerAvatarReceivedNotification))
                }
                .filter {
                    guard let userInfo = $0.userInfo,
                        let publicKey = userInfo["publicKey"] as? String else {
                            return false
                    }
                    guard publicKey == pk else {
                        return false
                    }
                    return true
                }
                .timeout(.seconds(60), scheduler: MainScheduler.instance)
                .map { notification in
                    guard let userInfo = notification.userInfo,
                        let path = userInfo["path"] as? String else {
                            return nil
                    }
                    
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path))
                        return UIImage(data: data)
                    } catch {
                        return nil
                    }
            }
        }
    }
    
    func getSignature(pk: String) -> Observable<String?> {
        return Observable.deferred {
            guard let bot = self.bot else {
                return .error(NSError())
            }
            
            let startObservable = bot.isConnected ? Observable.just(()) : self.botOnline.distinctUntilChanged().map { _ in () }
            return startObservable
                .flatMapLatest { _ -> Observable<Notification> in
                    let model = StrangerSignatureReq()
                    model.pk = pk.data(using: .utf8)
                    print("😺Get Signature: \(pk)");
                    self.toxManager.chats.sendStrangerMessage(model.data(), command: OCTToxStrangerCmd.signature, botFriendNumber: bot.friendNumber)
                    return NotificationCenter.default.rx.notification(Notification.Name(rawValue: kOCTStrangerSignatureReceivedNotification))
                }
                .timeout(.seconds(20), scheduler: MainScheduler.instance)
                .map { notification in
                    guard let data = notification.object as? Data else {
                        return nil
                    }
                    do {
                        let model = try StrangerSignatureRes.parse(from: data)
                        if let publicKey = String(bytes: model.pk, encoding: .utf8), pk == publicKey {
                            return String(bytes: model.signature, encoding: .utf8)
                        }
                        return nil
                    } catch {
                        return nil
                    }
            }
        }
    }
    
    func setNewBio(_ newBio: String) {
        bio = newBio
        let message = "/set \(newBio)"
        toxManager.chats.sendStrangerCommandMessage(message)
    }
    
    func findStrangers() -> Observable<[Stranger]?> {
        return Observable.deferred {
            guard let bot = self.bot else {
                return .error(NSError())
            }
            let startObservable = bot.isConnected ? Observable.just(()) : self.botOnline.distinctUntilChanged().map { _ in () }
            return startObservable
                .flatMapLatest { _ -> Observable<Notification> in
                    self.toxManager.chats.sendStrangerMessage(StrangerGetListReq().data(), command: OCTToxStrangerCmd.getList, botFriendNumber: bot.friendNumber)
                    return NotificationCenter.default.rx.notification(Notification.Name(rawValue: kOCTStrangerMessageReceivedNotification))
                }
                .timeout(.seconds(60), scheduler: MainScheduler.instance)
                .map { notification in
                    guard let data = notification.object as? Data else {
                        return nil
                    }
                    do {
                        let list = try StrangerGetListRes.parse(from: data)
                        return list.strangerArray as? [Stranger]
                    } catch {
                        return nil
                    }
            }
        }
    }
    
    func loadClassicWords() -> [String] {
        guard let filePath = Bundle.main.path(forResource: "string_classic_bio", ofType: "xml") else {
            return []
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return []
        }
        
        let xml = SWXMLHash.parse(data)
        return xml["resources"]["item"].all.compactMap { $0.element?.text }
    }
    
    // MARK: - Private
    private func addFriendNotification() {
        guard let bot = bot else {
            return
        }
        
        let predicate = NSPredicate(format: "uniqueIdentifier == %@", bot.uniqueIdentifier)
        
        let results = toxManager.objects.friends(predicate: predicate)
        
        friendToken = results.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update:
                if self.bot?.isConnected == true {
                    self.botOnline.onNext(true)
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    func findFriend(address: String?, friendState: Int = 0) -> OCTFriend? {
        guard let address = address else {
            return nil
        }
        let publicKey = String(address.prefix(Int(kOCTToxPublicKeyLength)))
        return toxManager.friends.friend(withPublicKey: publicKey, friendState: friendState)
    }
    
    func findFriendIgnoreState(address: String?) -> OCTFriend? {
        guard let address = address else {
            return nil
        }
        let publicKey = String(address.prefix(Int(kOCTToxPublicKeyLength)))
        return toxManager.friends.friend(withPublicKeyIgnoreState: publicKey)
    }
    
    private func cacheAvatarImage(pk: String) -> UIImage? {
        guard let dir = toxManager.managerGetFileStorage()?.pathForAvatarsDirectory as NSString? else {
            return nil
        }
        guard let fileName = (pk as NSString).appendingPathExtension("png") else {
            return nil
        }
        let path = dir.appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
