//
//  HomeViewModel.swift
//  Tok
//
//  Created by Bryce on 2018/12/1.
//  Copyright © 2018 Insight. All rights reserved.
//

import RxSwift
import RxCocoa
import Reachability

class HomeViewModel: NSObject {
    
    let isConnected: BehaviorRelay<Bool>
    
    let chatsCount: Driver<String?>
    
    let requestsCount: Driver<String?>
    
    let hasNewFeature: BehaviorRelay<String?>
    
    private let reachability = try! Reachability()
    
    private let disposeBag = DisposeBag()
    private let notificationManager: NotificationManager
    private var callManager: CallManager!
    fileprivate var friendsToken: RLMNotificationToken?
    
    let messageService: MessageService
    private let manager: OCTManager
    private let messageSender: MessagesSender
    fileprivate var messagesToken: RLMNotificationToken?
    
    private let userDefaultsManager: UserDefaultsManager
    
    private let friends: Results<OCTFriend>
    
    init(messageService: MessageService) {
        self.messageService = messageService
        self.manager = messageService.tokManager.toxManager
        self.messageSender = messageService.messageSender
        
        notificationManager = NotificationManager(messageService: messageService)
        isConnected = BehaviorRelay(value: false)
        
        chatsCount = notificationManager.chatsCountChanged.map { $0 > 0 ? "\($0)" : nil }.asDriver(onErrorJustReturn: nil)
        requestsCount = notificationManager.requestsCountChanged.map { $0 > 0 ? "\($0)" : nil }.asDriver(onErrorJustReturn: nil)
        
        let userDefaultsManager = UserDefaultsManager()
        let showNewFeature = userDefaultsManager.newFeatureForWallet
        hasNewFeature = BehaviorRelay(value: showNewFeature ? "New" : nil)
        self.userDefaultsManager = userDefaultsManager
        
        notificationManager.register()
        notificationManager.updateBadges()
        
        let predicate = NSPredicate(format: "publicKey BEGINSWITH %@ OR publicKey BEGINSWITH %@ OR publicKey BEGINSWITH %@", BotService.shared.groupBot.publicKey, BotService.shared.offlineBot.publicKey, BotService.shared.fileBot.publicKey) // it's realm bug, cannot use '=='
        friends = messageService.database.findFriends(predicate: predicate)
        
        super.init()
        startNotifier()
        addNotificationBlocks()
        manager.user.delegate = self
        
        hasNewFeature.accept(userDefaultsManager.showNewFeatureOnMe ? "New" : nil)
    }
    
    func startNotifier() {
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
        reachability.whenUnreachable = { _ in
            NSLog("❌❌❌Unreachable")
        }
        reachability.whenReachable = { reachability in
            NSLog("📶📶📶Reachable\(reachability.connection)")
            UserService.shared.bootstrap()
        }
    }
    
    func setupCallManager(presentingController: UIViewController) {
        callManager = CallManager(presentingController: presentingController, messageService: messageService)
        callManager.delegate = self
        
        NotificationCenter.default.rx.notification(Notification.Name.StartVoiceCall)
            .subscribe(onNext: { [weak self] noti in
                guard let chat = noti.userInfo?["chat"] as? OCTChat else { return }
                self?.callManager.callToChat(chat, enableVideo: false)
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(Notification.Name.StartVideoCall)
            .subscribe(onNext: { [weak self] noti in
                guard let chat = noti.userInfo?["chat"] as? OCTChat else { return }
                self?.callManager.callToChat(chat, enableVideo: true)
            })
            .disposed(by: disposeBag)
    }
    
    func hideNewFeature() {
        guard userDefaultsManager.showNewFeatureOnMe else {
            return
        }
        userDefaultsManager.showNewFeatureOnMe = false
    }
    
    deinit {
        friendsToken?.invalidate()
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
    
    func addNotificationBlocks() {
        friendsToken = friends.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update(let friends, _, _, _):
                guard let friends = friends else { return }
                #if DEBUG
                for i in 0..<friends.count {
                    if friends[i].isConnected {
                        NSLog("👏👏👏👏👏👏👏👏 %@ Connected", friends[i].nickname)
                        break
                    }
                    NSLog("😭😭😭😭😭😭 %@ offline", friends[i].nickname)
                }
                #endif
                self.updateConnectionState()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    func updateConnectionState() {
        if messageService.tokManager.tox.connectionStatus != .none {
            isConnected.accept(true)
        } else {
            let bots: [OCTFriend] = friends.toList()
            let connected = bots.contains(where: { messageService.tokManager.tox.friendConnectionStatus(withFriendNumber: $0.friendNumber, error: nil) != .none })
            isConnected.accept(connected)
        }
        
        // Pull remote nodes once
        if messageService.database.findFriend(withPublicKey: BotService.shared.groupBot.publicKey)?.isConnected == true {
            _ = pullRemoteNodes
        }
    }
    
    private lazy var pullRemoteNodes: Void = { [weak self] in
        self?.messageService.pullNodes()
    }()
}

extension HomeViewModel: OCTSubmanagerUserDelegate {
    func submanagerUser(_ submanager: OCTSubmanagerUser, connectionStatusUpdate connectionStatus: OCTToxConnectionStatus) {
        performAsynchronouslyOnMainThread {
            let isOnline = (connectionStatus != .none)
            
            if isOnline {
                UserService.shared.uploadPushManager.uploadPushTokenIfNeeded()
            } else {
                #if DEBUG
                NSLog("❌❌❌Tox offline")
                #endif
            }
            self.updateConnectionState()
        }
    }
}

extension HomeViewModel: CallCoordinatorDelegate {
    func callCoordinator(_ coordinator: CallManager, notifyAboutBackgroundCallFrom caller: OCTCall, userInfo: String) {
        notificationManager.showCallNotificationWithCaller(caller, userInfo: userInfo)
    }
    
    func callCoordinatorDidStartCall(_ coordinator: CallManager) {
        //        delegate?.activeSessionCoordinatorDidStartCall(self)
    }
    
    func callCoordinatorDidFinishCall(_ coordinator: CallManager) {
        //        delegate?.activeSessionCoordinatorDidFinishCall(self)
    }
}
