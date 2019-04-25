//
//  HomeCoordinator.swift
//  Tok
//
//  Created by Bryce on 2018/11/20.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

extension NSNotification.Name {
    static let ShowChat = NSNotification.Name("ShowChat")
}

class HomeCoordinator: BaseCoordinator<Void> {
    
    private let window: UIWindow
    private let manager: OCTManager
    
    init(window: UIWindow, manager: OCTManager) {
        self.window = window
        self.manager = manager
        
        super.init()
        
        NotificationCenter.default.rx.notification(Notification.Name.ShowChat)
            .subscribe(onNext: { [unowned self] notification in
                guard let home = self.window.rootViewController as? HomeViewController,
                    let chatsNav = home.viewControllers?.first as? UINavigationController,
                    let chat = notification.userInfo?["chat"] as? OCTChat else {
                        return
                }
                
                home.selectedIndex = 0
                if chatsNav.viewControllers.count > 1 {
                    chatsNav.popToRootViewController(animated: false)
                }
                
                let chatVC = ConversationViewController(chat: chat)
                chatsNav.pushViewController(chatVC, animated: false)
            })
            .disposed(by: disposeBag)
        
        setupOfflineBot()
    }
    
    override func start() -> Observable<Void> {
        return Observable.deferred {
            let viewModel = HomeViewModel(toxMananger: self.manager)
            let viewController = HomeViewController(viewModel: viewModel)
            self.window.rootViewController = viewController
            self.window.makeKeyAndVisible()
            
            return UserService.shared.didLogout.take(1)
        }
    }
    
    private func setupOfflineBot() {
        manager.offlineBotPublicKey = OfflineBotModel().publicKey
    }
}
