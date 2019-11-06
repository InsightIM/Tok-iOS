//
//  NeverlandMeViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class NeverlandMeViewController: BaseViewController {
    
    lazy var discoverStyleView = DiscoverStyleView(editStyle: true)
    
    lazy var joinButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Join the Neverland", comment: ""))
        button.addTarget(self, action: #selector(self.didJoin), for: .touchUpInside)
        return button
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("You can create a new ID to add friends", comment: "")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokFootnote
        return label
    }()
    
    private let findFriendService: FindFriendService
    init(findFriendService: FindFriendService) {
        self.findFriendService = findFriendService
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("My Style", comment: "")
        
        if !findFriendService.isAnonymous {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Quit", comment: ""), style: .plain, target: self, action: #selector(self.didQuit))
        }
        
        view.backgroundColor = .tokBackgroundColor
        view.addSubview(discoverStyleView)
        
        if findFriendService.isAnonymous {
            view.addSubview(joinButton)
            view.addSubview(tipLabel)
            discoverStyleView.snp.makeConstraints { (make) in
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
                make.top.equalTo(self.view.safeArea.top).offset(16)
            }
            joinButton.snp.makeConstraints { (make) in
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
                make.top.equalTo(discoverStyleView.snp.bottom).offset(40)
                make.height.equalTo(44)
                make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            }
            tipLabel.snp.makeConstraints { (make) in
                make.top.equalTo(joinButton.snp.bottom).offset(18)
                make.centerX.equalToSuperview()
            }
        } else {
            discoverStyleView.snp.makeConstraints { (make) in
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
                make.top.equalTo(self.view.safeArea.top).offset(16)
                make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            }
        }
        
        discoverStyleView.avatarImageView.image = AvatarManager.shared.userAvatar(messageService: findFriendService.messageService)
        discoverStyleView.nameLabel.text = UserService.shared.nickName
        discoverStyleView.text = findFriendService.bio
        
        discoverStyleView.editButton.addTarget(self, action: #selector(self.didEdit), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        discoverStyleView.text = findFriendService.bio
    }
    
    @objc
    func didQuit() {
        let message = NSLocalizedString("You won't be shown to others any more", comment: "")
        let ok = NSLocalizedString("OK", comment: "")
        let action: AlertViewManager.Action = { [weak self] in
            self?.findFriendService.sendStop()
            self?.navigationController?.popViewController(animated: true)
        }
        AlertViewManager.showMessageSheet(with: message, actions: [(ok, .destructive, action)])
    }
    
    @objc
    func didEdit() {
        let vc = EditMyStyleViewController(findFriendService: findFriendService)
        vc.textView.text = discoverStyleView.text
        vc.didEdit = { [weak self] in
            self?.discoverStyleView.text = self?.findFriendService.bio
        }
        
        let navigationController = UINavigationController(rootViewController: vc)
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @objc
    func didJoin() {
        findFriendService.sendStart()
        navigationController?.popViewController(animated: true)
    }
}
