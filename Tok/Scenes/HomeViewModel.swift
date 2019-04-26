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
