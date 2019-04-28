//
//  HomeViewModel.swift
//  Tok
//
//  Created by Bryce on 2018/12/1.
//  Copyright © 2018 Insight. All rights reserved.
//

import RxSwift
import RxCocoa

class HomeViewModel: NSObject {
    
    let isConnected: BehaviorRelay<Bool>
    
    let chatsCount: Driver<String?>
    
    let requestsCount: Driver<String?>
    
    let hasNewFeature: BehaviorRelay<String?>
    
    private let disposeBag = DisposeBag()
    private let notificationManager: NotificationManager
    private var callManager: CallManager!
    
    private let manager: OCTManager
    fileprivate var messagesToken: RLMNotificationToken?
    
    private let userDefaultsManager: UserDefaultsManager
    
    init(toxMananger: OCTManager) {
        manager = toxMananger
        
        notificationManager = NotificationManager(toxMananger: manager)
        isConnected = BehaviorRelay(value: false)
        
        chatsCount = notificationManager.chatsCountChanged.map { $0 > 0 ? "\($0)" : nil }.asDriver(onErrorJustReturn: nil)
        requestsCount = notificationManager.requestsCountChanged.map { $0 > 0 ? "\($0)" : nil }.asDriver(onErrorJustReturn: nil)
        
        let userDefaultsManager = UserDefaultsManager()
        let showNewFeature = (userDefaultsManager.showFindFriendBotTip || userDefaultsManager.showOfflineMessageBotTip)
        hasNewFeature = BehaviorRelay(value: showNewFeature ? "New" : nil)
        self.userDefaultsManager = userDefaultsManager
        
        notificationManager.register()
        notificationManager.updateBadges()
        
        super.init()
        
        manager.user.delegate = self
        
        hasNewFeature.accept(userDefaultsManager.showNewFeatureOnMe ? "New" : nil)
    }
    
    func setupCallManager(presentingController: UIViewController) {
        callManager = CallManager(presentingController: presentingController, submanagerCalls: manager.calls, submanagerObjects: manager.objects)
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
        userDefaultsManager.showNewFeatureOnMe = false
    }
    
    deinit {
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
}

extension HomeViewModel: OCTSubmanagerUserDelegate {
    func submanagerUser(_ submanager: OCTSubmanagerUser, connectionStatusUpdate connectionStatus: OCTToxConnectionStatus) {
        let isOnline = (connectionStatus != .none)
        self.isConnected.accept(isOnline)
        
        if isOnline {
            UploadPushManager.shared.uploadPushTokenIfNeeded()
        }
    }
}

extension HomeViewModel: CallCoordinatorDelegate {
    func callCoordinator(_ coordinator: CallManager, notifyAboutBackgroundCallFrom caller: String, userInfo: String) {
        notificationManager.showCallNotificationWithCaller(caller, userInfo: userInfo)
    }
    
    func callCoordinatorDidStartCall(_ coordinator: CallManager) {
        //        delegate?.activeSessionCoordinatorDidStartCall(self)
    }
    
    func callCoordinatorDidFinishCall(_ coordinator: CallManager) {
        //        delegate?.activeSessionCoordinatorDidFinishCall(self)
    }
}
