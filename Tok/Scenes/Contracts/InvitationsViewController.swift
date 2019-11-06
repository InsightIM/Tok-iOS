//
//  InvitationsViewController.swift
//  Tok
//
//  Created by Bryce on 2018/7/6.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class InvitationsViewController: BaseViewController {

    let messageService: MessageService
    let toxMananger: OCTManager
    let isOutgoing: Bool
    fileprivate let requests: Results<OCTFriendRequest>
    fileprivate var requestsToken: RLMNotificationToken?
    
    init(messageService: MessageService, isOutgoing: Bool) {
        self.messageService = messageService
        self.toxMananger = messageService.tokManager.toxManager
        self.isOutgoing = isOutgoing
        
        let predicate = NSPredicate(format: "isOutgoing == %@", NSNumber(value: isOutgoing))
        self.requests = toxMananger.objects.friendRequests(predicate: predicate).sortedResultsUsingProperty("dateInterval", ascending: false)
        
        super.init()
        
        hidesBottomBarWhenPushed = true
        
        addNotificationBlocks()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 64
        tableView.register(cellType: FriendRequestCell.self)
        
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    lazy var emptyView = FriendRequestListEmptyView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = isOutgoing
            ? NSLocalizedString("My Request", comment: "")
            : NSLocalizedString("Friend Request", comment: "")
        
        view.backgroundColor = .tokBackgroundColor
        
        if !isOutgoing {
            let myRequest = UIBarButtonItem(title: NSLocalizedString("My Request", comment: ""), style: .plain, target: self, action: #selector(self.didClickMyRequest))
            navigationItem.rightBarButtonItem = myRequest
        }
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    func setupEmptyView(isShow: Bool) {
        if isShow {
            view.addSubview(emptyView)
            emptyView.snp.makeConstraints { (make) in
                make.center.equalToSuperview()
                make.left.right.equalToSuperview()
            }
        } else {
            emptyView.removeFromSuperview()
        }
    }
    
    deinit {
        requestsToken?.invalidate()
    }
    
    @objc
    func didClickMyRequest() {
        let vc = InvitationsViewController(messageService: messageService, isOutgoing: true)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension InvitationsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: FriendRequestCell = tableView.dequeueReusableCell(for: indexPath)
        
        let request = requests[indexPath.row]
        cell.avatarImageView.image = AvatarManager.shared.image(bySenderId: request.publicKey, messageService: messageService)
        cell.topLabel.text = request.publicKey
        
        if isOutgoing {
            let friend = toxMananger.friends.friend(withPublicKeyIgnoreState: request.publicKey)
            
            cell.descLabel.text = friend?.nickname
            cell.status = .accepted
            cell.statusLabel.text = NSLocalizedString("Request sent", comment: "")
        } else {
            cell.descLabel.text = request.message
            cell.status = FriendRequestCell.Status(rawValue: request.status) ?? .waitting
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard isOutgoing == false else { return }
        
        let request = requests[indexPath.row]
        let vc = FriendRequestViewController(toxMananger: toxMananger, request: request)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: NSLocalizedString("Delete", comment: "")) { [unowned self] (_, index) in
            
            let title = NSLocalizedString("Delete this friend request?", comment: "")
            let deleteAction: AlertViewManager.Action = { [unowned self] in
                let request = self.requests[indexPath.row]
                if let friend = self.toxMananger.friends.friend(withPublicKey: request.publicKey, friendState: 1) {
                    try? self.toxMananger.friends.remove(friend)
                }
                self.toxMananger.friends.remove(request)
            }
            
            AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)])
        }
        
        deleteAction.backgroundColor = .tokNotice
        return [deleteAction]
    }
}

extension InvitationsViewController {
    func addNotificationBlocks() {
        setupEmptyView(isShow: requests.count == 0)
        requestsToken = requests.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let requests, _, _, _):
                guard let requests = requests else {
                    return
                }
                self.setupEmptyView(isShow: requests.count == 0)
                self.tableView.reloadData()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
