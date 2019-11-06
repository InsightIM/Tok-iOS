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
    static let UpdateChatAvatar = NSNotification.Name("UpdateChatAvatar")
}

class HomeCoordinator: BaseCoordinator<Void> {
    
    private let window: UIWindow
    private let manager: OCTManager
    private let tokManager: TokManager
    private var lockView: PasscodeLockView?

    private let messageService: MessageService
    
    init(window: UIWindow, tokManager: TokManager) {
        self.window = window
        self.manager = tokManager.toxManager
        
        self.tokManager = tokManager
        self.messageService = MessageService(tokManager: tokManager)
        
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
                
                let chatVC = ConversationViewController()
                chatVC.dataSource = ConversationDataSource(messageService: self.messageService, chat: chat)
                chatsNav.pushViewController(chatVC, animated: false)
            })
            .disposed(by: disposeBag)
    }
    
    override func start() -> Observable<Void> {
        return Observable.deferred {
            let viewModel = HomeViewModel(messageService: self.messageService)
            let viewController = HomeViewController(viewModel: viewModel)
            self.window.rootViewController = viewController
            self.window.makeKeyAndVisible()
            
            self.addLockViewAndShow()
            DynamicDomainService.shared.updateIfNeeded()
            
            return UserService.shared.didLogout.take(1)
        }
    }
    
    private func addLockViewAndShow() {

        lockView?.removeFromSuperview()
        if UserDefaultsManager().pinEnabled == true {

            let lockV = PasscodeLockView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
            lockView = lockV
            self.window.addSubview(lockV)

            lockView?.showFingerprintTouch()
        }
    }
}
