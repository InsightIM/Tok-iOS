//
//  NeverlandFriendViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxSwiftExt

class NeverlandFriendViewController: BaseViewController {
    
    var addAction: (() -> Void)?
    
    let disposeBag = DisposeBag()
    
    lazy var discoverStyleView = DiscoverStyleView()
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Add", comment: ""))
        button.addTarget(self, action: #selector(self.didClickAdd), for: .touchUpInside)
        return button
    }()

    private let findFriendService: FindFriendService
    private let stranger: Stranger
    private var friend: OCTFriend?
    init(findFriendService: FindFriendService, stranger: Stranger) {
        self.findFriendService = findFriendService
        self.stranger = stranger
        self.friend = findFriendService.findFriend(address: String(bytes: stranger.tokId, encoding: .utf8))
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("A friend comes from Neverland", comment: "")

        view.backgroundColor = .tokBackgroundColor
        discoverStyleView.layer.cornerRadius = 4
        discoverStyleView.layer.masksToBounds = true
        view.addSubview(discoverStyleView)
        
        if friend == nil {
            view.addSubview(addButton)
            discoverStyleView.snp.makeConstraints { (make) in
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
                make.top.equalTo(self.view.safeArea.top).offset(16)
            }

            addButton.snp.makeConstraints { (make) in
                make.leading.trailing.equalTo(discoverStyleView)
                make.height.equalTo(48)
                make.top.equalTo(discoverStyleView.snp.bottom).offset(40)
                make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            }
        } else {
            discoverStyleView.snp.makeConstraints { (make) in
                make.leading.equalTo(16)
                make.trailing.equalTo(-16)
                make.top.equalTo(self.view.safeArea.top).offset(16)
                make.bottom.equalTo(self.view.safeArea.bottom).offset(-100)
            }
        }
        
        let nickName = String(bytes: stranger.nickName, encoding: .utf8) ?? "?"
        discoverStyleView.nameLabel.text = nickName
        discoverStyleView.text = String(bytes: stranger.signature, encoding: .utf8)
        discoverStyleView.avatarImageView.image = AvatarManager.shared.image(bySenderId: friend?.publicKey ?? "?", messageService: findFriendService.messageService)
        
        bindData()
    }
    
    private func bindData() {
        guard friend == nil else {
            return
        }
        guard let address = String(bytes: stranger.tokId, encoding: .utf8) else {
            return
        }
        
        let pk = String(address.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Int(kOCTToxPublicKeyLength)))
        if let hasAvatar = String(bytes: stranger.avatarFileName, encoding: .utf8),
            hasAvatar.isNotEmpty {
            findFriendService.getAvatar(pk: pk)
                .debug("getAvatar")
                .catchErrorJustReturn(nil)
                .ignore(nil)
                .observeOn(MainScheduler.instance)
                .bind(to: discoverStyleView.avatarImageView.rx.image)
                .disposed(by: disposeBag)
        }
        
        findFriendService.getSignature(pk: pk)
            .debug("getSignature")
            .catchErrorJustReturn(nil)
            .ignore(nil)
            .observeOn(MainScheduler.instance)
            .map { text in
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 15
                return NSAttributedString(string: text!, attributes: [.paragraphStyle: paragraphStyle,
                                                                      .font: UIFont.systemFont(ofSize: 16)])
            }
            .bind(to: discoverStyleView.detailTextView.rx.attributedText)
            .disposed(by: disposeBag)
    }
    
    @objc
    func didClickAdd() {
        addAction?()
    }
}
