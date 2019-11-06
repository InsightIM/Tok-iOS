//
//  AddProxyViewController.swift
//  Tok
//
//  Created by Bryce on 2019/9/30.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import IQKeyboardManagerSwift

class ProxyDetailViewController: BaseViewController {
    
    var completion: (() -> Void)?
    
    lazy var serverCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Server", comment: "")
        return cell
    }()
    
    lazy var portCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Port", comment: "")
        cell.nameField.keyboardType = .numberPad
        return cell
    }()
    
    lazy var usernameCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Username (Optional)", comment: "")
        return cell
    }()
    
    lazy var passwordCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Password (Optional)", comment: "")
        cell.nameField.isSecureTextEntry = true
        return cell
    }()
    
    lazy var shareCell: LinkCell = LinkCell()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.estimatedRowHeight = 44
        tableView.sectionFooterHeight = CGFloat.leastNormalMagnitude
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    lazy var backButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(self.backButtonClick))
        item.tintColor = .tokBlack
        return item
    }()
    
    lazy var doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: self, action: #selector(self.doneButtonClick))
    
    lazy var datasource: [(title: String?, cells: [UITableViewCell])] = [
        ("SOCKS5", [serverCell, portCell]),
//        (nil, [usernameCell, passwordCell]),
        (nil, [shareCell])
    ]
    
    private let messageService: MessageService
    private let model: ProxyModel?
    init(messageService: MessageService, model: ProxyModel? = nil) {
        self.messageService = messageService
        self.model = model
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Proxy", comment: "")
        
        navigationItem.leftBarButtonItem = backButton
        navigationItem.rightBarButtonItem = doneButton
        
        view.backgroundColor = .tokBackgroundColor
        tableView.backgroundColor = .tokBackgroundColor
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        if let model = self.model {
            serverCell.nameField.text = model.server
            portCell.nameField.text = "\(model.port)"
            usernameCell.nameField.text = model.username
            passwordCell.nameField.text = model.password
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = false
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
}

private extension ProxyDetailViewController {
    @objc
    func doneButtonClick() {
        guard let (server, port) = checkShareable() else {
            return
        }
        
        var allModels = ProxyModel.retrieve().filter { $0 != model }
        let selected = model == nil ? allModels.isEmpty : (model?.selected ?? false)
        let proxy = ProxyModel(server: server, port: port, username: usernameCell.nameField.text, password: passwordCell.nameField.text, selected: selected)
        if selected {
            allModels.insert(proxy, at: 0)
        } else {
            allModels.append(proxy)
        }
        ProxyModel.store(models: allModels)
        
        dismiss(animated: true, completion: completion)
    }
    
    @objc
    func backButtonClick() {
        dismiss(animated: true, completion: nil)
    }
    
    func checkShareable() -> (server: String, port: UInt)? {
        guard let server = serverCell.nameField.text,
            let portString = portCell.nameField.text,
            let port = UInt(portString),
            server.validateIpOrHost(),
            portString.validatePort() else {
                return nil
        }
        return (server: server, port: port)
    }
}

extension ProxyDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return datasource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datasource[section].cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return datasource[indexPath.section].cells[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return datasource[section].title
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return datasource[section].title != nil ? 40 : CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 14)
        header.textLabel?.textColor = UIColor("#83838D")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tableView.cellForRow(at: indexPath) is LinkCell, let result = checkShareable() else { return }
        let tip = NSLocalizedString("Click to save", comment: "")
        let shareLink = "tok://proxy?server=\(result.server)&port=\(result.port)&protocol=socks5\n\(tip)"
        share(text: shareLink, messageService: messageService)
    }
}
