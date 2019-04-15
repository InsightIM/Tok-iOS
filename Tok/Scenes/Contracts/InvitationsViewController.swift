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

    fileprivate let submanagerFriends: OCTSubmanagerFriends
    fileprivate let requests: Results<OCTFriendRequest>
    fileprivate var requestsToken: RLMNotificationToken?
    fileprivate let avatarManager = AvatarManager()
    
    override init() {
        self.submanagerFriends = UserService.shared.toxMananger!.friends
        self.requests = UserService.shared.toxMananger!.objects.friendRequests()
        
        super.init()
        
        hidesBottomBarWhenPushed = true
        
        addNotificationBlocks()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 55
        tableView.register(cellType: ContractDetailCell.self)
        
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("New Friends", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    deinit {
        requestsToken?.invalidate()
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
        let cell: ContractDetailCell = tableView.dequeueReusableCell(for: indexPath)
        
        let request = requests[indexPath.row]
        cell.avatarImageView.image = avatarManager.avatarFromString("", diameter: 36)
        cell.nameLabel.text = request.publicKey
        cell.detailLabel.text = request.message
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let request = requests[indexPath.row]
        
        let acceptAction: AlertViewManager.Action = { [weak self] in
            do {
                try self?.submanagerFriends.approve(request)
            }
            catch let error as NSError {
                ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
            }
            return ()
        }
        
        let declineAction: AlertViewManager.Action = { [weak self] in
            self?.submanagerFriends.remove(request)
            return ()
        }
        
        AlertViewManager.showMessageSheet(with: NSLocalizedString("New Friend Request", comment: ""), actions: [
            (NSLocalizedString("Accept", comment: ""), .default, acceptAction),
            (NSLocalizedString("Decline", comment: ""), .destructive, declineAction)
            ])
    }
}

extension InvitationsViewController {
    func addNotificationBlocks() {
        requestsToken = requests.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let requests, _, _, _):
                guard requests != nil else {
                    return
                }
                
                self.tableView.reloadData()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
