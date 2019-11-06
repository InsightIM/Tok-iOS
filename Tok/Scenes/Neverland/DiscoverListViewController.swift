//
//  DiscoverListViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Action

class DiscoverListViewController: BaseViewController {
    
    var dataSource: [Stranger] = []
    
    lazy var profileView: DiscoverProfileView = {
        let view = UIView.ts_viewFromNib(DiscoverProfileView.self)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.didClickProfile))
        view.addGestureRecognizer(tap)
        return view
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorColor = .clear
        tableView.rowHeight = 85
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellType: StrangerCell.self)
        return tableView
    }()
    
    lazy var refreshButton: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIColor.tokBlue.createImage(), for: .normal)
        button.setBackgroundImage(UIColor.tokBlue.withAlphaComponent(0.6).createImage(), for: .highlighted)
        button.layer.cornerRadius = 48
        button.layer.masksToBounds = true
        button.setTitle(NSLocalizedString("More", comment: ""), for: .normal)
        button.addTarget(self, action: #selector(self.refresh), for: .touchUpInside)
        return button
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
        prefersNavigationBarHidden = true
        view.backgroundColor = .clear
        
        view.addSubview(profileView)
        profileView.snp.makeConstraints { (make) in
            make.height.equalTo(64)
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(self.view.safeArea.top)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(self.profileView.snp.bottom)
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
        }
        
        view.addSubview(refreshButton)
        refreshButton.snp.makeConstraints { (make) in
            make.top.equalTo(tableView.snp.bottom).offset(40)
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-20)
            make.size.equalTo(96)
            make.centerX.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        profileView.avatarImageView.image = findFriendService.isAnonymous
            ? UIImage(named: "AnonymousAvatar")
            : AvatarManager.shared.userAvatar(messageService: findFriendService.messageService)
    }
    
    private let disposeBag = DisposeBag()
    @objc
    func refresh() {
        ProgressHUD.showLoadingHUD(in: self.view)
        findFriendService.findStrangers()
            .subscribe(onNext: { [weak self] result in
                guard let self = self else { return }
                ProgressHUD.hideLoadingHUD(in: self.view)
                if let result = result, !result.isEmpty {
                    self.reloadData(newDataSource: result)
                } else {
                    if let first = self.navigationController?.viewControllers.first {
                        let vc = NoMoreStrangerViewController(findFriendService: self.findFriendService)
                        self.navigationController?.setViewControllers([first, vc], animated: true)
                    }
                }
                }, onError: { [weak self] error in
                    ProgressHUD.hideLoadingHUD(in: self?.view)
            })
            .disposed(by: disposeBag)
    }
    
    func reloadData(newDataSource: [Stranger]) {
        let newCount = newDataSource.count
        let oldCount = dataSource.count
        let diffCount = newCount - oldCount
        
        dataSource = newDataSource
        tableView.beginUpdates()
        if diffCount == 0 {
            tableView.reloadSections(IndexSet(integersIn: 0..<oldCount), with: .left)
        } else if diffCount > 0 {
            tableView.insertSections(IndexSet(integersIn: oldCount..<newCount), with: .right)
            tableView.reloadSections(IndexSet(integersIn: 0..<oldCount), with: .left)
        } else {
            tableView.deleteSections(IndexSet(integersIn: newCount..<oldCount), with: .left)
            tableView.reloadSections(IndexSet(integersIn: 0..<newCount), with: .left)
        }
        tableView.endUpdates()
    }
    
    @objc
    private func didClickProfile() {
        let vc = NeverlandMeViewController(findFriendService: findFriendService)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func addFriend(address: String?, nickname: String?) {
        guard let address = address else { return }
        let alertController = UIAlertController(title: NSLocalizedString("Set an Alias for him/her in your Contacts", comment: ""), message: "", preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { textField in
            textField.text = nickname
            textField.placeholder = NSLocalizedString("Set an Alias (option)", comment: "")
            textField.clearButtonMode = .whileEditing
        })
        
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak alertController, weak self] _ in
            guard let alertController = alertController, let textField = alertController.textFields?.first, let self = self else { return }
            
            let message = self.findFriendService.bio ?? ""
            let alias = textField.text
            
            let result = self.findFriendService.messageService.friendService.sendFriendRequest(address: address, message: message, alias: alias)
            switch result {
            case .success:
                self.tableView.reloadData()
            case .failure(let error):
                ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
            }
        }
        
        alertController.addAction(confirmAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
}

extension DiscoverListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: StrangerCell.self)
        let model = dataSource[indexPath.section]
        let nickName = String(bytes: model.nickName, encoding: .utf8) ?? "?"
        cell.nameLabel.text = nickName
        cell.detailLabel.text = String(bytes: model.signature, encoding: .utf8)
        
        guard let address = String(bytes: model.tokId, encoding: .utf8) else {
            cell.avatarImageView.image = nil
            cell.addButton.isEnabled = true
            cell.addAction = nil
            return cell
        }
        
        let publicKey = String(address.prefix(Int(kOCTToxPublicKeyLength)))
        let avatar = AvatarManager.shared.image(bySenderId: publicKey, messageService: findFriendService.messageService)
        
        if findFriendService.findFriendIgnoreState(address: String(bytes: model.tokId, encoding: .utf8)) != nil {
            cell.avatarImageView.image = avatar
            cell.addButton.isEnabled = false
        } else {
            cell.avatarImageView.image = avatar
            cell.addButton.isEnabled = true
            cell.addAction = { [weak self] in
                let address = String(bytes: model.tokId, encoding: .utf8)
                let nickname = String(bytes: model.nickName, encoding: .utf8)
                self?.addFriend(address: address, nickname: nickname)
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 8
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = dataSource[indexPath.section]
        let vc = NeverlandFriendViewController(findFriendService: findFriendService, stranger: model)
        vc.addAction = { [weak self] in
            let address = String(bytes: model.tokId, encoding: .utf8)
            let nickname = String(bytes: model.nickName, encoding: .utf8)
            self?.addFriend(address: address, nickname: nickname)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
}
