//
//  GroupMembersViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2019/1/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class GroupMembersViewController: BaseViewController {

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 56
        tableView.register(cellType: GroupMemberCell.self)
        
        tableView.keyboardDismissMode = .interactive
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    private var dataSource: [Peer] = []
    private var page: UInt32 = 0
    private let chat: OCTChat
    private let messageService: MessageService
    private let disposeBag = DisposeBag()
    
    init(chat: OCTChat, messageService: MessageService) {
        self.chat = chat
        self.messageService = messageService
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var titleView: ConversationTitleView = {
        return ConversationTitleView(chat: chat, messageService: messageService)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = titleView
        let title = chat.title ?? "Group \(chat.groupNumber)"
        let subtitle = "\(chat.groupMemebersCount) " + NSLocalizedString("Members", comment: "")
        titleView.userStatusView.isHidden = true
        titleView.update(title: title, subtitle: subtitle, userStatus: .online, muted: chat.isMute, verified: false)
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        loadData()
        
        tableView.es.addInfiniteScrolling { [unowned self] in
            self.loadData()
        }
    }
    
    private func loadData() {
        if page == 0 {
            ProgressHUD.showLoadingHUD(in: self.view)
        }
        messageService.getPeerList(groupId: UInt64(chat.groupNumber), page: page)
            .subscribe(onNext: { [weak self] (peers, end) in
                if self?.page == 0 {
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                }
                self?.page += 1
                self?.dataSource.append(contentsOf: peers)
                self?.tableView.reloadData()
                
                self?.tableView.es.stopLoadingMore()
                if end || peers.isEmpty {
                    self?.tableView.es.noticeNoMoreData()
                }
            }, onError: { [weak self] _ in
                self?.tableView.es.stopLoadingMore()
                ProgressHUD.showTextHUD(withText: NSLocalizedString("Something went wrong and try again later", comment: ""), in: self?.view)
            })
            .disposed(by: disposeBag)
    }
}

extension GroupMembersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GroupMemberCell = tableView.dequeueReusableCell(for: indexPath)
        
        let model = dataSource[indexPath.row]
        cell.avatarImageView.image = model.avatar
        cell.nameLabel.text = model.nickname
        cell.detailLabel.text = model.confirmFlag == 1 ? NSLocalizedString("Pending", comment: "") : nil
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = dataSource[indexPath.row]
        let senderId = model.publicKey
        guard senderId != self.messageService.tokManager.tox.publicKey else {
            let vc = ProfileViewController(messageService: self.messageService)
            self.navigationController?.pushViewController(vc, animated: true)
            return
        }
        let viewController = FriendViewController(messageService: messageService, publicKey: senderId, chat: chat)
        navigationController?.pushViewController(viewController, animated: true)
    }
}
