//
//  GroupRecommendViewController.swift
//  Tok
//
//  Created by Bryce on 2019/8/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxSwiftExt

struct GroupRecommendModel {
    let avatar: UIImage
    let name: String
    let description: String?
    let shareId: String?
    let isVerified: Bool
    
    init(info: GroupRecommendInfo, database: Database) {
        if let chat = database.findGroupChat(by: info.groupId) {
            avatar = AvatarManager.shared.chatAvatar(chatId: chat.uniqueIdentifier, database: database) ?? UIImage(named: "GroupRecommendDefault")!
            name = chat.title ?? "Group \(info.groupId)"
            description = chat.groupDescription
        } else {
            avatar = UIImage(named: "GroupRecommendDefault")!
            name = String(data: info.groupName, encoding: .utf8) ?? "Group \(info.groupId)"
            description = String(data: info.remark, encoding: .utf8)
        }
        
        shareId = String(data: info.shareId, encoding: .utf8)
        isVerified = verifiedGroupShareIds.contains(shareId)
    }
}

class GroupRecommendViewController: BaseViewController {

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 68
        tableView.register(cellType: ChatsCell.self)
        
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    private var dataSource: [GroupRecommendModel] = []
    private var page: UInt32 = 0
    private let messageService: MessageService
    private let manager: OCTManager
    private let disposeBag = DisposeBag()
    
    init(messageService: MessageService) {
        self.messageService = messageService
        self.manager = messageService.tokManager.toxManager
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("50 Popular Public Groups", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        loadData()
        
        tableView.es.addInfiniteScrolling { [weak self] in
            self?.loadData()
        }
    }
    
    private func loadData() {
        if page == 0 {
            ProgressHUD.showLoadingHUD(in: self.view)
        }
        messageService.getRecommendGroupList(page: page)
            .filterMap { [weak self] (datas, end) -> FilterMap<([GroupRecommendModel], Bool)> in
                guard let self = self else { return .ignore }
                let models = datas.map {
                    GroupRecommendModel(info: $0, database: self.messageService.database)
                }
                return .map((models, end))
            }
            .subscribe(onNext: { [weak self] (models, end) in
                guard let self = self else { return }
                if self.page == 0 {
                    ProgressHUD.hideLoadingHUD(in: self.view)
                }
                self.page += 1
                
                self.dataSource.append(contentsOf: models)
                self.tableView.reloadData()
                
                if end || models.isEmpty || self.page > 100 {
                    self.tableView.es.noticeNoMoreData()
                } else if self.page % 3 != 0 {
                    self.loadData()
                } else {
                    self.tableView.es.stopLoadingMore()
                }
                }, onError: { [weak self] _ in
                    self?.tableView.es.stopLoadingMore()
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Something went wrong and try again later", comment: ""), in: self?.view)
            })
            .disposed(by: disposeBag)
    }
}

extension GroupRecommendViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ChatsCell = tableView.dequeueReusableCell(for: indexPath)
        
        let model = dataSource[indexPath.row]
        
        cell.avatarImageView.image = model.avatar
        cell.nameLabel.text = model.name
        cell.lastMessageLabel.text = model.description
        cell.verifiedImageView.isHidden = !model.isVerified
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = dataSource[indexPath.row]
        guard let shareId = model.shareId else {
            return
        }
        let vc = GroupViewerViewController(groupShareId: shareId, messageService: messageService)
        navigationController?.pushViewController(vc, animated: true)
    }
}
