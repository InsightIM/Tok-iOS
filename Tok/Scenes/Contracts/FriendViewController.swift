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
    
    let disposeBag = DisposeBag()
    
    var friend: OCTFriend?
    var peer: OCTPeer?
    
    let titles: [[String]] = [
        ["Me"],
        [NSLocalizedString("Public Key", comment: ""), NSLocalizedString("Remark", comment: "")]
    ]
    
    lazy var messagesButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Messages", comment: ""), cornerRadius: 25)
        return button
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        return view
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 20
        tableView.sectionFooterHeight = 0.01
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = footerView
        tableView.register(cellType: PortraitCell.self)
        tableView.register(cellType: FriendInfoCell.self)
        
        return tableView
    }()
    
    init(friend: OCTFriend) {
        self.friend = friend
        
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    init(peer: OCTPeer) {
        self.peer = peer
        
        if let publicKey = peer.publicKey {
            self.friend = UserService.shared.toxMananger!.objects.friends(predicate: NSPredicate(format: "publicKey == %@", publicKey)).firstObject
        }
        
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Profile", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        if self.friend != nil {
            footerView.addSubview(messagesButton)
            messagesButton.snp.makeConstraints({ (make) in
                make.top.equalTo(20).priority(.high)
                make.left.equalTo(16).priority(.high)
                make.right.equalTo(-16).priority(.high)
                make.height.equalTo(50)
            })
            
            messagesButton.rx.tap
                .subscribe(onNext: { [weak self] _ in
                    if let chat = UserService.shared.toxMananger!.chats.getOrCreateChat(with: self?.friend) {
                        self?.navigationController?.popViewController(animated: false)
                        NotificationCenter.default.post(name: NSNotification.Name.ShowChat, object: nil, userInfo: ["chat": chat])
                    }
                })
                .disposed(by: disposeBag)
        }
    }
}

extension FriendViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: PortraitCell = tableView.dequeueReusableCell(for: indexPath)
            cell.accessoryType = .none
            
            let avatar = friend?.avatar ?? peer?.avatar
            let nickname = friend?.nickname ?? peer?.nickname
            let name = (friend?.name ?? friend?.nickname) ?? peer?.nickname
            cell.avatarImageView.image = avatar
            cell.nameLabel.text = nickname
            if let name = name {
                cell.userNameLabel.text = NSLocalizedString("Name", comment: "") + ": \(name)"
            }
            
            cell.detailLabel.text = friend?.statusMessage ?? NSLocalizedString("Hey there! I'm using Tok.", comment: "")
            return cell
        } else {
            let cell: FriendInfoCell = tableView.dequeueReusableCell(for: indexPath)
            let title = titles[indexPath.section][indexPath.row]
            cell.nameLabel.text = title
            cell.detailLabel.text = indexPath.row == 0 ? (friend?.publicKey ?? peer?.publicKey) : (friend?.nickname ?? peer?.nickname)
            cell.accessoryType = indexPath.row == 0 ? .none : .disclosureIndicator
            cell.selectionStyle = indexPath.row == 0 ? .none : .default
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 88
        } else {
            if indexPath.row == 0 {
                return 70
            }
        }
        return 44
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        return tableView.sectionHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            guard let cell = tableView.cellForRow(at: indexPath) as? PortraitCell else { return }
            
            let avatar = friend?.avatar ?? peer?.avatar
            let data = YBImageBrowseCellData()
            data.imageBlock = { avatar }
            data.sourceObject = cell.avatarImageView
            
            let browser = YBImageBrowser()
            browser.dataSourceArray = [data]
            browser.show()
        case 1:
            if indexPath.row == 1 {
                let alertController = UIAlertController(title: NSLocalizedString("Alias", comment: ""), message: "", preferredStyle: .alert)
                alertController.addTextField(configurationHandler: { [weak self] textField in
                    textField.text = (self?.friend?.nickname ?? self?.peer?.nickname)
                    textField.clearButtonMode = .whileEditing
                })
                
                let confirmAction = UIAlertAction(title: "OK", style: .default) { [unowned self, weak alertController] _ in
                    guard let alertController = alertController else { return }
                
                    var newNickName = (self.friend?.nickname ?? self.friend?.publicKey) ?? ""
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
            }
        default:
            break
        }
    }
}

extension OCTFriend {
    var avatar: UIImage? {
        if let avatarData = avatarData {
            return UIImage(data: avatarData)
        }
        return AvatarManager().avatarFromString(nickname, diameter: 64)
    }
}

extension OCTPeer {
    var avatar: UIImage? {
        if let avatarData = avatarData {
            return UIImage(data: avatarData)
        }
        return AvatarManager().avatarFromString(nickname ?? "?", diameter: 64)
    }
}
