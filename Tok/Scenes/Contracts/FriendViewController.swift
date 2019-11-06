//
//  FriendViewController.swift
//  Tok
//
//  Created by Bryce on 2018/7/10.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

class FriendViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    
    private var friend: OCTFriend?
    private var peer: OCTPeer?
    
    private var titles: [String] = [
        "", NSLocalizedString("Public Key", comment: ""), NSLocalizedString("Bio", comment: "")
    ]
    
    private lazy var messagesButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Messages", comment: ""))
        button.addTarget(self, action: #selector(self.didClickMessages), for: .touchUpInside)
        return button
    }()
    
    private lazy var removeButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Remove", comment: ""), color: UIColor.tokNotice)
        button.addTarget(self, action: #selector(self.didClickRemove), for: .touchUpInside)
        return button
    }()
    
    private lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        
        let border = UIView()
        border.backgroundColor = UIColor.tokLine
        view.addSubview(border)
        border.snp.makeConstraints { (make) in
            make.height.equalTo(1.0 / UIScreen.main.scale)
            make.left.right.top.equalToSuperview()
        }
        
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 30
        tableView.sectionFooterHeight = 0.01
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = footerView
        tableView.register(cellType: FriendPortraitCell.self)
        tableView.register(cellType: FriendInfoCell.self)
        tableView.register(cellType: SwitchCell.self)
        
        return tableView
    }()
    
    private var nickname: String
    private let messageService: MessageService
    private let publicKey: String
    
    init(messageService: MessageService, friendPublicKey: String) {
        self.messageService = messageService
        self.publicKey = friendPublicKey
        self.friend = messageService.database.findFriend(withPublicKey: friendPublicKey)
        self.nickname = friend?.nickname ?? "Tok \(friendPublicKey.prefix(4))"

        super.init()
        hidesBottomBarWhenPushed = true
        
        appendSectionsIfNeeded()
    }
    
    private var removable = false // group owner can remove peer
    private var chat: OCTChat? = nil
    init(messageService: MessageService, publicKey: String, chat: OCTChat?) {
        self.messageService = messageService
        self.publicKey = publicKey
        self.removable = chat?.ownerPublicKey == messageService.tokManager.tox.publicKey
        self.chat = chat
        
        self.friend = messageService.database.findFriend(withPublicKey: publicKey)
        if self.friend == nil {
            self.peer = messageService.database.findPeer(withPublicKey: publicKey)
        }
        
        if let name = self.friend?.nickname {
            self.nickname = name
        } else if let name = peer?.nickname {
            self.nickname = name
        } else {
            self.nickname = "Tok \(publicKey.prefix(4))"
        }
        super.init()
        hidesBottomBarWhenPushed = true

        appendSectionsIfNeeded()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var friendStyle = false
    private func appendSectionsIfNeeded() {
        if friend != nil {
            friendStyle = true
            titles.append(contentsOf: [NSLocalizedString("Alias", comment: ""), NSLocalizedString("New Group", comment: "")])
        } else if peer != nil {
            friendStyle = false
            titles.append(NSLocalizedString("Alias", comment: ""))
        }
        titles.append("")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Profile", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        if let friend = self.friend, friend.friendState == 0 {
            if let chat = chat, chat.isGroup, removable {
                footerView.addSubview(removeButton)
                footerView.addSubview(messagesButton)
                
                removeButton.snp.makeConstraints({ (make) in
                    make.top.equalTo(20).priority(.high)
                    make.left.equalTo(16).priority(.high)
                    make.height.equalTo(50)
                })
                
                messagesButton.snp.makeConstraints({ (make) in
                    make.top.equalTo(20).priority(.high)
                    make.left.equalTo(removeButton.snp.right).offset(10).priority(.high)
                    make.right.equalTo(-16).priority(.high)
                    make.height.equalTo(50)
                    make.width.equalTo(removeButton)
                })
            } else {
                footerView.addSubview(messagesButton)
                messagesButton.snp.makeConstraints({ (make) in
                    make.top.equalTo(20).priority(.high)
                    make.left.equalTo(16).priority(.high)
                    make.right.equalTo(-16).priority(.high)
                    make.height.equalTo(50)
                })
            }
        } else if let chat = chat, chat.isGroup, removable {
            footerView.addSubview(removeButton)
            removeButton.snp.makeConstraints({ (make) in
                make.top.equalTo(20).priority(.high)
                make.left.equalTo(16).priority(.high)
                make.right.equalTo(-16).priority(.high)
                make.height.equalTo(50)
            })
        }
    }
    
    @objc
    func didClickMessages() {
        guard let friend = self.friend else { return }
        let chat = self.messageService.database.findOrCreateChat(friend: friend)
        self.navigationController?.popViewController(animated: false)
        NotificationCenter.default.post(name: NSNotification.Name.ShowChat, object: nil, userInfo: ["chat": chat])
    }
    
    @objc
    func didClickRemove() {
        let title = NSLocalizedString("Are you sure you want to remove this person from group?", comment: "")
        
        let okAction: AlertViewManager.Action = { [unowned self] in
            guard let chat = self.chat else { return }
            self.messageService.tokManager.toxManager.chats.kickoutPeer(self.publicKey, fromGroupChat: chat)
            self.navigationController?.popViewController(animated: true)
        }
        
        AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("OK", comment: ""), .destructive, okAction)])
    }
}

extension FriendViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: FriendPortraitCell = tableView.dequeueReusableCell(for: indexPath)
            cell.accessoryType = .none
            
            let publicKey = self.publicKey
            let avatar = AvatarManager.shared.image(bySenderId: publicKey, messageService: messageService)
            let name = (friend?.name ?? friend?.nickname) ?? peer?.nickname
            cell.avatarImageView.image = avatar
            cell.nameLabel.text = nickname
            if let name = name {
                cell.userNameLabel.text = NSLocalizedString("Nickname", comment: "") + ": \(name)"
            }
            cell.verified = friend?.isVerified ?? false
            return cell
        }
        
        let blockUserCell: () -> UITableViewCell = {
            let cell: SwitchCell = tableView.dequeueReusableCell(for: indexPath)
            cell.nameLabel.text = NSLocalizedString("Block User", comment: "")
            cell.switchButton.isOn = (self.friend?.blocked ?? self.peer?.blocked) ?? false
            cell.switchButton.rx.isOn
                .skip(1)
                .subscribe(onNext: { [unowned self, weak cell] isOn in
                    guard isOn else {
                        self.messageService.database.blockUser(publicKey: self.publicKey, isBlock: isOn)
                        return
                    }
                    
                    let title = String(format: NSLocalizedString("Do you want to block %@ from messaging and calling you on Tok", comment: ""), self.nickname)
                    let action: AlertViewManager.Action = { [weak self] in
                        guard let self = self else { return }
                        self.messageService.database.blockUser(publicKey: self.publicKey, isBlock: isOn)
                    }
                    AlertViewManager.showMessageSheet(with: title,
                                                      interactive: false,
                                                      actions: [(NSLocalizedString("Block", comment: ""), UIAlertAction.Style.destructive, action)], cancelTitle: NSLocalizedString("Cancel", comment: ""), customCancelAction: { [weak cell] in
                                                        cell?.switchButton.setOn(false, animated: true)
                    })
                })
                .disposed(by: cell.disposeBag)
            return cell
        }
        
        if indexPath.section == 4 {
            if friendStyle {
                let cell: FriendInfoCell = tableView.dequeueReusableCell(for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Create Group Chat", comment: "")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                return cell
            }
            return blockUserCell()
        }
        if indexPath.section == 5 {
            return blockUserCell()
        }
        
        let cell: FriendInfoCell = tableView.dequeueReusableCell(for: indexPath)
        if indexPath.section == 1 {
            cell.textLabel?.text = publicKey
            cell.accessoryType = .none
            cell.selectionStyle = .none
        } else if indexPath.section == 2 {
            cell.textLabel?.text = friend?.statusMessage ?? NSLocalizedString("Hey there! I'm using Tok.", comment: "")
        } else if indexPath.section == 3 {
            let nickname = (friend?.nickname ?? peer?.nickname) ?? "Tok \(publicKey.prefix(4))"
            cell.textLabel?.text = nickname
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let title = titles[section]
        return title
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 14)
        header.textLabel?.textColor = UIColor("#83838D")
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        if section == titles.count - 1 { // block user
            return 12
        }
        return tableView.sectionHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            guard let cell = tableView.cellForRow(at: indexPath) as? FriendPortraitCell else { return }
            
            let publicKey = (friend?.publicKey ?? peer?.publicKey) ?? "?"
            let avatar = AvatarManager.shared.image(bySenderId: publicKey, messageService: messageService)
            let data = YBImageBrowseCellData()
            data.imageBlock = { avatar }
            data.sourceObject = cell.avatarImageView
            
            let browser = YBImageBrowser()
            browser.dataSourceArray = [data]
            browser.show()
        case 3:
            let alertController = UIAlertController(title: NSLocalizedString("Alias", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField(configurationHandler: { [weak self] textField in
                textField.text = (self?.friend?.nickname ?? self?.peer?.nickname)
                textField.clearButtonMode = .whileEditing
            })
            
            let confirmAction = UIAlertAction(title: "OK", style: .default) { [unowned self, weak alertController] _ in
                guard let alertController = alertController else { return }
                
                var newNickName = (self.friend?.name ?? self.friend?.publicKey) ?? ""
                if let input = alertController.textFields?.first?.text, input.isNotEmpty {
                    newNickName = input
                }
                
                if let friend = self.friend {
                    UserService.shared.toxMananger!.objects.change(friend, nickname: newNickName)
                } else if let peer = self.peer {
                    if newNickName.isEmpty == true {
                        newNickName = (peer.nickname ?? peer.publicKey) ?? ""
                    }
                    UserService.shared.toxMananger!.objects.change(peer, nickname: newNickName)
                }
                
                self.tableView.reloadData()
            }
            
            alertController.addAction(confirmAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        default:
            if indexPath.section == 4 {
                if friendStyle {
                    let vc = GroupTypeViewController(messageService: messageService, friend: friend)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
}
