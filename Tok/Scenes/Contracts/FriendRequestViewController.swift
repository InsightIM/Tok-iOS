//
//  FriendRequestViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/19.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import IQKeyboardManagerSwift

class FriendRequestViewController: BaseViewController {
    
    lazy var refuseButton: UIButton = {
        let button = UIButton()
        button.fcBorderStyle(title: NSLocalizedString("Refuse", comment: ""))
        button.addTarget(self, action: #selector(self.didClickRefuse), for: .touchUpInside)
        return button
    }()
    
    lazy var acceptButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Accept", comment: ""))
        button.addTarget(self, action: #selector(self.didClickAccept), for: .touchUpInside)
        return button
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        return view
    }()
    
    lazy var publicKeyCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.textLabel?.copyable = true
        cell.textLabel?.textColor = .tokBlack
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }()
    
    lazy var messageCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.textLabel?.copyable = true
        cell.textLabel?.textColor = .tokBlack
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }()
    
    lazy var setAliasCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Set an Alias (option)", comment: "")
        return cell
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.estimatedRowHeight = 44
        tableView.sectionHeaderHeight = 40
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = footerView
        
        return tableView
    }()
    
    let toxMananger: OCTManager
    let request: OCTFriendRequest
    init(toxMananger: OCTManager, request: OCTFriendRequest) {
        self.toxMananger = toxMananger
        self.request = request
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Friend Request", comment: "")
        view.backgroundColor = .tokBackgroundColor
        tableView.backgroundColor = .tokBackgroundColor
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        footerView.addSubview(refuseButton)
        footerView.addSubview(acceptButton)
        refuseButton.snp.makeConstraints { (make) in
            make.leading.equalTo(20).priorityHigh()
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }
        acceptButton.snp.makeConstraints { (make) in
            make.trailing.equalTo(-20).priorityHigh()
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
            make.width.equalTo(refuseButton).priorityHigh()
            make.leading.equalTo(refuseButton.snp.trailing).offset(15).priorityHigh()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = false
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    @objc
    func didClickRefuse() {
        toxMananger.friends.refuse(request)
        navigationController?.popViewController(animated: true)
    }
    
    @objc
    func didClickAccept() {
        do {
            let publicKey = request.publicKey
            try toxMananger.friends.approve(request, alias: setAliasCell.nameField.text)
            toxMananger.chats.sendOfflineFriendAcceptRequest(withPublicKey: publicKey)
            navigationController?.popViewController(animated: true)
        }
        catch let error as NSError {
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
        }
    }
}

extension FriendRequestViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            publicKeyCell.textLabel?.text = request.publicKey
            return publicKeyCell
        case 1:
            messageCell.textLabel?.text = request.message
            return messageCell
        case 2:
            return setAliasCell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Public Key", comment: "")
        case 1:
            return NSLocalizedString("Message", comment: "")
        case 2:
            return NSLocalizedString("Alias", comment: "")
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 14)
        header.textLabel?.textColor = UIColor("#83838D")
    }
}
