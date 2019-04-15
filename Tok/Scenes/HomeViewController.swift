//
//  HomeViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class HomeViewController: UITabBarController {
    
    private let disposeBag = DisposeBag()
    
    private lazy var chats = ChatsViewController()
    private lazy var contracts = ContactsViewController()
    private lazy var me = MeViewController()
    
    private let viewDidAppear = PublishSubject<Void>()
    
    let viewModel: HomeViewModel
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isTranslucent = false
        
        chats.tabBarItem = UITabBarItem(title: NSLocalizedString("Tok", comment: ""), image: UIImage(named: "TabbarChats"), selectedImage: UIImage(named: "TabbarChatsHL"))
        let chatsNav = UINavigationController(rootViewController: chats)
        
        contracts.tabBarItem = UITabBarItem(title: NSLocalizedString("Contacts", comment: ""), image: UIImage(named: "TabbarContacts"), selectedImage: UIImage(named: "TabbarContactsHL"))
        let contractsNav = UINavigationController(rootViewController: contracts)
        
        me.tabBarItem = UITabBarItem(title: NSLocalizedString("Me", comment: ""), image: UIImage(named: "TabbarMe"), selectedImage: UIImage(named: "TabbarMeHL"))
        let meNav = UINavigationController(rootViewController: me)
        
        viewControllers = [chatsNav, contractsNav, meNav]
        
        tabBar.clipsToBounds = true
        let borderView = UIView()
        borderView.backgroundColor = .tokLine
        tabBar.addSubview(borderView)
        borderView.snp.makeConstraints { (make) in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        
        bindViewModel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewDidAppear.onNext(())
    }
    
    private func bindViewModel() {
        viewModel.chatsCount
            .drive(chats.tabBarItem.rx.badgeValue)
            .disposed(by: disposeBag)
        
        viewModel.requestsCount
            .drive(contracts.tabBarItem.rx.badgeValue)
            .disposed(by: disposeBag)
        
        viewModel.hasNewFeature
            .bind(to: me.tabBarItem.rx.badgeValue)
            .disposed(by: disposeBag)
        
        Observable.combineLatest(viewModel.isConnected.asObservable(), viewDidAppear.asObservable()) { isConnected, _ in
            return isConnected
            }
            .subscribe(onNext: { [unowned self] isConnected in
                self.toggleNotificationBanner(isOnline: isConnected)
            })
            .disposed(by: disposeBag)
    }
    
    deinit {
        NotificationBannerManager.shared.hideInStatusBar()
    }
}

extension HomeViewController {
    func toggleNotificationBanner(isOnline: Bool) {
        if isOnline {
            NotificationBannerManager.shared.hideInStatusBar()
        } else {
            NotificationBannerManager.shared.showInStatusBar(NSLocalizedString("Connecting", comment: ""))
        }
    }
}
