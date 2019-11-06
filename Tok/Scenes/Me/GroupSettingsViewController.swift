//
//  GroupSettingsViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/24.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class GroupSettingsViewController: BaseViewController {
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.sectionHeaderHeight = 30
        tableView.separatorColor = .tokLine
        tableView.tableFooterView = UIView()
//        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 12))
        
        return tableView
    }()
    
    lazy var contactsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = NSLocalizedString("Contacts", comment: "")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .tokBlack
        cell.selectionStyle = .none
        return cell
    }()
    
    lazy var nobodyCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = NSLocalizedString("Nobody", comment: "")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .tokBlack
        cell.selectionStyle = .none
        return cell
    }()
    
    private var dataSource: [UITableViewCell] = []
    private var userDefaultsManager = UserDefaultsManager()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Group Setting", comment: "")
        tableView.backgroundColor = .tokBackgroundColor
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        dataSource = [contactsCell, nobodyCell]
        updateCells()
    }
    
    func updateCells() {
        switch userDefaultsManager.joinGroupSetting {
        case .contacts:
            contactsCell.accessoryType = .checkmark
            nobodyCell.accessoryType = .none
        case .nobody:
            contactsCell.accessoryType = .none
            nobodyCell.accessoryType = .checkmark
        }
    }
}

extension GroupSettingsViewController: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dataSource[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Who can add me to Groups", comment: "")
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return NSLocalizedString("You can restrict who can add you to groups.", comment: "")
    }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = .tokFootnote
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        userDefaultsManager.joinGroupSetting = indexPath.row == 0 ? .contacts : .nobody
        updateCells()
    }
}
