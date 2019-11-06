//
//  ForwardChatViewController.swift
//  Tok
//
//  Created by Bryce on 2019/1/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ForwardChatCell: UITableViewCell {
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = UIColor.black
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 40, height: 40))
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(20)
            make.centerY.equalTo(avatarImageView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ForwardChatViewController: BaseViewController {
    
    let viewModel: ForwardMessageViewModel
    
    fileprivate let disposeBag = DisposeBag()
    
    fileprivate let chats: Results<OCTChat>
    
    fileprivate lazy var selectFriendCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.accessoryType = .disclosureIndicator
        return cell
    }()
    
    init(viewModel: ForwardMessageViewModel) {
        self.viewModel = viewModel
        
        chats = UserService.shared.toxMananger!.objects.normalChats().sortedResultsUsingProperty("lastActivityDateInterval", ascending: false)
        
        super.init()
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
        
        tableView.rowHeight = 60
        tableView.register(cellType: ForwardChatCell.self)
        
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Select a Chat", comment: "")
        
        let backItem = UIBarButtonItem(title: NSLocalizedString("Close", comment: ""), style: .plain, target: nil, action: nil)
        backItem.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        navigationItem.leftBarButtonItem = backItem
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }

}

extension ForwardChatViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            selectFriendCell.textLabel?.text = NSLocalizedString("New Chat", comment: "")
            return selectFriendCell
        } else {
            let chat = chats[indexPath.row]
            
            let cell: ForwardChatCell = tableView.dequeueReusableCell(for: indexPath)
            cell.avatarImageView.image = AvatarManager.shared.image(with: chat)
            if chat.isGroup {
                cell.nameLabel.text = (chat.title ?? "Group \(chat.groupNumber)")
            } else {
                let friend = chat.friends?.firstObject() as? OCTFriend
                cell.nameLabel.text = friend?.nickname
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            let vc = ForwardFriendViewController(viewModel: viewModel)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            let chat = chats[indexPath.row]
            viewModel.sendMessage(to: chat)
            dismiss(animated: true, completion: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : NSLocalizedString("Latest Chats", comment: "")
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 30
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 13)
        header.textLabel?.textColor = UIColor("#83838D")
    }
}
