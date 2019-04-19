//
//  BotInfoViewController.swift
//  Tok
//
//  Created by Bryce on 2019/3/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift

class BotInfoViewController: BaseViewController {

    private let disposeBag = DisposeBag()
    
    private var bot: BotModelProtocol
    private var friend: OCTFriend
    
    let titles: [String] = [
        "",
        NSLocalizedString("Bio", comment: ""),
        NSLocalizedString("Public Key", comment: "")
    ]
    
    lazy var messagesButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Messages", comment: ""))
        return button
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Add Bot", comment: ""))
        return button
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 70))
        return view
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.estimatedRowHeight = 60
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = footerView
        tableView.register(cellType: BotPortraitCell.self)
        tableView.register(cellType: UITableViewCell.self)
        
        return tableView
    }()
    
    init(bot: BotModelProtocol) {
        self.bot = bot
        friend = bot.getBot() ?? bot.defaultBot
        
        super.init()
        
        hidesBottomBarWhenPushed = true        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = friend.nickname
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        setupButton()
    }
    
    func setupButton() {
        footerView.subviews.forEach { subview in
            subview.removeFromSuperview()
        }
        
        if bot.beAdded {
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
        } else {
            footerView.addSubview(addButton)
            addButton.snp.makeConstraints({ (make) in
                make.top.equalTo(20).priority(.high)
                make.left.equalTo(16).priority(.high)
                make.right.equalTo(-16).priority(.high)
                make.height.equalTo(50)
            })
            
            addButton.rx.tap
                .flatMap { [unowned self] _ -> Observable<Void> in
                    let address = self.bot.address
                    return FriendService.sendRequest(address: address, message: "add bot")
                }
                .subscribe(onNext: { [weak self] _ in
                    self?.setupButton()
                    }, onError: { [weak self] error in
                        ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
                })
                .disposed(by: disposeBag)
        }
    }
}

extension BotInfoViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return titles[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: BotPortraitCell = tableView.dequeueReusableCell(for: indexPath)
            cell.accessoryType = .none
            
            let avatar = friend.avatar
            let nickname = friend.nickname
            cell.avatarImageView.image = avatar
            cell.nameLabel.text = nickname
            return cell
        } else {
            let cell: UITableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.textLabel?.text = indexPath.section == 1 ? friend.statusMessage : friend.publicKey
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textColor = .tokBlack
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
            cell.textLabel?.copyable = true
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            guard let cell = tableView.cellForRow(at: indexPath) as? PortraitCell else { return }
            
            let avatar = friend.avatar
            let data = YBImageBrowseCellData()
            data.imageBlock = { avatar }
            data.sourceObject = cell.avatarImageView
            
            let browser = YBImageBrowser()
            browser.dataSourceArray = [data]
            browser.show()
        default:
            break
        }
    }
}
