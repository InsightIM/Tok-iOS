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
    
    private var chats: ChatsViewController
    private var contracts: ContactsViewController
    private var me: MeViewController
    
    private let viewDidAppear = PublishSubject<Void>()
    
    let viewModel: HomeViewModel
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        chats = ChatsViewController(messageService: viewModel.messageService)
        contracts = ContactsViewController(messageService: viewModel.messageService)
        me = MeViewController(messageService: viewModel.messageService)
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
        
        let navigationControllers = [chatsNav, contractsNav, meNav]
        navigationControllers.forEach {
            $0.navigationBar.backIndicatorImage = UIImage(named: "NavbarBack")
            $0.navigationBar.backIndicatorTransitionMaskImage = UIImage(named: "NavbarBack")
        }
        viewControllers = navigationControllers
        
        
        tabBar.clipsToBounds = true
        let borderView = UIView()
        borderView.backgroundColor = .tokLine
        tabBar.addSubview(borderView)
        borderView.snp.makeConstraints { (make) in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        
        bindViewModel()
        
        viewModel.setupCallManager(presentingController: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewDidAppear.onNext(())
    }
    
    private func bindViewModel() {
        self.rx.didSelect
            .subscribe(onNext: { [unowned self] nav in
                guard let nav = nav as? UINavigationController,
                    nav.viewControllers.first == self.me,
                    self.me.tabBarItem.badgeValue != nil else {
                        return
                }
                self.me.tabBarItem.badgeValue = nil
                self.viewModel.hideNewFeature()
            })
            .disposed(by: disposeBag)
        
        viewModel.chatsCount
            .distinctUntilChanged()
            .debug("chatsCount")
            .drive(chats.tabBarItem.rx.badgeValue)
            .disposed(by: disposeBag)
        
        viewModel.requestsCount
            .drive(contracts.tabBarItem.rx.badgeValue)
            .disposed(by: disposeBag)
        
        viewModel.hasNewFeature
            .bind(to: me.tabBarItem.rx.badgeValue)
            .disposed(by: disposeBag)
        
        viewModel.isConnected
            .debug("isConnected")
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: false)
            .drive(onNext: { [weak self] isConnected in
                guard let self = self else { return }
                self.chats.titleView.isConnected = isConnected
            })
            .disposed(by: disposeBag)
    }
    
    deinit {
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
}
