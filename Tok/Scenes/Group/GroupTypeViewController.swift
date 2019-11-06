//
//  GroupTypeViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/16.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class GroupTypeViewController: BaseViewController {
    
    let friend: OCTFriend?
    let messageService: MessageService
    init(messageService: MessageService, friend: OCTFriend? = nil) {
        self.messageService = messageService
        self.friend = friend
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.sectionHeaderHeight = 12
        tableView.separatorColor = .tokLine
        tableView.tableFooterView = UIView()
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 12))
        
        return tableView
    }()
    
    lazy var privateCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = NSLocalizedString("Private Group", comment: "")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .tokBlack
        cell.selectionStyle = .none
        return cell
    }()
    
    lazy var publicCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = NSLocalizedString("Public Group", comment: "")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .tokBlack
        cell.selectionStyle = .none
        return cell
    }()
    
    lazy var nextBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: NSLocalizedString("Next", comment: ""), style: .plain, target: self, action: #selector(self.didClickNext))
        item.isEnabled = false
        item.tintColor = .tokLink
        return item
    }()
    
    var dataSource: [UITableViewCell] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Group Type", comment: "")
        navigationItem.rightBarButtonItem = nextBarButtonItem
        tableView.backgroundColor = .tokBackgroundColor
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        dataSource = [privateCell, publicCell]
    }
    
    @objc
    func didClickNext() {
        let vc = CreateGroupViewController(messageService: messageService, friend: friend)
        vc.publicGroup = tableView.indexPathForSelectedRow?.row == 1
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension GroupTypeViewController: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dataSource[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return NSLocalizedString("· Group type cannot be modified after creation.\n· Private groups only can be joined if you were invited and can not be found in search.\n· Public groups can be found in search and everyone can join.", comment: "")
    }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = .tokBlack
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        nextBarButtonItem.isEnabled = true
        for (i, cell) in dataSource.enumerated() {
            cell.accessoryType = i == indexPath.row ? .checkmark : .none
        }
    }
}
