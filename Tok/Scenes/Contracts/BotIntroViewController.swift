//
//  BotIntroViewController.swift
//  Tok
//
//  Created by Bryce on 2019/4/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import Action

class BotIntroViewController: BaseViewController {

    private let disposeBag = DisposeBag()
    
    private let titles: [String] = [
        "",
        NSLocalizedString("Add this bot to send offline messages with friends", comment: ""),
    ]
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.estimatedRowHeight = 60
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellType: BotPortraitCell.self)
        tableView.register(cellType: IntroductionCell.self)
        
        return tableView
    }()
    
    private let bot = OfflineBotModel()
    private lazy var friend: OCTFriend = {
        let friend: OCTFriend = bot.getBot() ?? bot.defaultBot
        return friend
    }()
    
    let addBotAction = Action<String, Void> { address in
        return FriendService.sendRequest(address: address, message: "add bot")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        titleString = NSLocalizedString("OfflineMessageBot", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        addBotAction.elements
            .subscribe(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        addBotAction.executing
            .subscribe(onNext: { [weak self] executing in
                if executing {
                    ProgressHUD.showLoadingHUD(in: self?.view)
                } else {
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                }
            })
            .disposed(by: disposeBag)
        
        addBotAction.errors
            .subscribe(onNext: { [weak self] error in
                switch error {
                case .notEnabled:
                    print("")
                case .underlyingError(let error):
                    ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
                }
            })
            .disposed(by: disposeBag)
    }
}

extension BotIntroViewController: UITableViewDataSource, UITableViewDelegate {
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
            let cell: IntroductionCell = tableView.dequeueReusableCell(for: indexPath)
            cell.titleLabel.text = NSLocalizedString("How to send offline messages?", comment: "")
            cell.detailLabel.text = NSLocalizedString("1. Add this bot on both sides.\n2. Send text messages as usual.", comment: "")
            return cell
        } else {
            let cell: BotPortraitCell = tableView.dequeueReusableCell(for: indexPath)
            
            let avatar = friend.avatar
            let nickname = friend.nickname
            cell.avatarImageView.image = avatar
            cell.nameLabel.text = nickname
            cell.added = bot.beAdded
            
            cell.addButton.rx.bind(to: addBotAction, input: bot.address)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            let vc = IntroductionViewController()
            navigationController?.pushViewController(vc, animated: true)
        default:
            let vc = BotInfoViewController(bot: bot)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

