//
//  SetGroupNameViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2018/9/15.
//  Copyright © 2018年 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

let GroupedPadding: CGFloat = 20

class SetGroupNameViewController: BaseViewController {

    var dataSource: [Friend] = []
    var publicGroup: Bool = false
    
    private let disposeBag = DisposeBag()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.rowHeight = 56
        tableView.sectionHeaderHeight = 40
        tableView.sectionFooterHeight = 0.01
        tableView.register(cellType: GroupMemberCell.self)
        
        tableView.keyboardDismissMode = .interactive
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    private lazy var inputCell = GroupNameInputCell()
    
    private lazy var groupTypeCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = NSLocalizedString("Public Group", comment: "")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .tokBlack
        cell.selectionStyle = .none
        return cell
    }()
    
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Set Group Name", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let next = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: self, action: #selector(self.didClickNext))
        next.tintColor = .tokLink
        navigationItem.rightBarButtonItem = next
    }
    
    @objc
    func didClickNext() {
        self.inputCell.endEditing(true)
        guard let name = self.inputCell.nameField.text, name.isNotEmpty else {
            ProgressHUD.showTextHUD(withText: NSLocalizedString("Group name is required", comment: ""), in: self.view)
            return
        }
        
        ProgressHUD.showLoadingHUD(in: self.view)
        
        let groupType = self.publicGroup ? 1 : 0
        return self.messageService.createGroup(name: name, groupType: groupType)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] groupNumber in
                guard let self = self else { return }
                ProgressHUD.hideLoadingHUD(in: self.view)
                
                self.navigationController?.popToRootViewController(animated: false)
                
                self.dataSource.forEach { friend in
                    self.messageService.invite(friendPublicKey: friend.publicKey, groupNumber: groupNumber)
                }
                
                if let chat = self.messageService.database.findGroupChat(by: UInt64(groupNumber)) {
                    NotificationCenter.default.post(name: NSNotification.Name.ShowChat, object: nil, userInfo: ["chat": chat])
                    NotificationCenter.default.post(name: NSNotification.Name.UpdateChatAvatar, object: nil, userInfo: ["chat": chat])
                }
                }, onError: { [weak self] error in
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                    
                    let text = NSLocalizedString("Create group failed", comment: "")
                    ProgressHUD.showTextHUD(withText: text, in: self?.view, afterDelay: 1.5)
            })
            .disposed(by: disposeBag)
    }
}

extension SetGroupNameViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 2 ? dataSource.count : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return inputCell
        }
        if indexPath.section == 1 {
            groupTypeCell.textLabel?.text = publicGroup
                ? NSLocalizedString("Public Group", comment: "")
                : NSLocalizedString("Private Group", comment: "")
            return groupTypeCell
        }
        
        let cell: GroupMemberCell = tableView.dequeueReusableCell(for: indexPath)
        
        let friend = dataSource[indexPath.row]
        cell.avatarImageView.image = AvatarManager.shared.image(bySenderId: friend.publicKey, messageService: messageService)
        cell.nameLabel.text = friend.nickname
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return NSLocalizedString("Group Name", comment: "")
        case 1: return NSLocalizedString("Group Type", comment: "")
        default: return NSLocalizedString("Members", comment: "") + "(\(dataSource.count))"
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = UIColor("#83838D")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
