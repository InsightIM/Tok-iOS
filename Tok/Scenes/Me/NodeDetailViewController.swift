//
//  NodeDetailViewController.swift
//  Tok
//
//  Created by Bryce on 2019/10/5.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import IQKeyboardManagerSwift

class NetworkProtocolCell: UITableViewCell {
    
    var networkProtocol: NodeModel.NetworkProtocol = .UDP {
        didSet {
            detailTextLabel?.text = networkProtocol.rawValue
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .disclosureIndicator
        
        textLabel?.font = UIFont.systemFont(ofSize: 16)
        textLabel?.textColor = UIColor.tokBlack
        textLabel?.text = NSLocalizedString("Network Protocol Type", comment: "")
        
        detailTextLabel?.font = UIFont.systemFont(ofSize: 16)
        detailTextLabel?.textColor = UIColor.tokFootnote
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NodeDetailViewController: BaseViewController {
    
    var completion: (() -> Void)?
    
    lazy var serverCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Node Address", comment: "")
        return cell
    }()
    
    lazy var portCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Node Port", comment: "")
        cell.nameField.keyboardType = .numberPad
        return cell
    }()
    
    lazy var publicKeyCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Node Public Key", comment: "")
        return cell
    }()
    
    lazy var networkProtocolCell = NetworkProtocolCell()
    
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
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    lazy var backButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(self.backButtonClick))
        item.tintColor = .tokBlack
        return item
    }()
    
    lazy var doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: self, action: #selector(self.doneButtonClick))
    
    lazy var datasource: [[UITableViewCell]] = [
        [serverCell, portCell, publicKeyCell],
        [networkProtocolCell],
        [shareCell]
    ]
    
    private let messageService: MessageService
    private let model: NodeModel?
    init(messageService: MessageService, model: NodeModel? = nil) {
        self.messageService = messageService
        self.model = model
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Bootstrap Node", comment: "")
        
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
            portCell.nameField.text = String(model.port)
            publicKeyCell.nameField.text = model.publicKey
            networkProtocolCell.networkProtocol = model.networkProtocol
        } else {
            networkProtocolCell.networkProtocol = .UDP
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

private extension NodeDetailViewController {
    @objc
    func doneButtonClick() {
        guard let result = checkShareable() else {
            return
        }
        
        let networkProtocol = networkProtocolCell.networkProtocol
        let node = NodeModel(server: result.server, port: result.port, publicKey: result.publicKey, networkProtocol: networkProtocol)
        
        var allModels = NodeModel.retrieve().filter { $0 != model }
        allModels.insert(node, at: 0)
        
        NodeModel.store(models: allModels)
        
        dismiss(animated: true, completion: completion)
    }
    
    @objc
    func backButtonClick() {
        dismiss(animated: true, completion: nil)
    }
    
    func checkShareable() -> (server: String, port: UInt, publicKey: String)? {
        guard let server = serverCell.nameField.text,
            let portString = portCell.nameField.text,
            let publicKey = publicKeyCell.nameField.text?.trim(),
            server.validateIpOrHost(),
            portString.validatePort(),
            let port = UInt(portString),
            publicKey.count == kOCTToxPublicKeyLength else {
                return nil
        }
        return (server: server, port: port, publicKey: publicKey)
    }
    
    func showNetworkProtocols(indexPath: IndexPath) {
        guard tableView.cellForRow(at: indexPath) is NetworkProtocolCell else { return }
        AlertViewManager.showActionSheet(with: [
            ("UDP", .default, { [unowned self] in
                self.networkProtocolCell.networkProtocol = .UDP
            }),
            ("TCP", .default, { [unowned self] in
                self.networkProtocolCell.networkProtocol = .TCP
            })
        ])
    }
    
    func share(indexPath: IndexPath) {
        guard tableView.cellForRow(at: indexPath) is LinkCell, let result = checkShareable() else { return }
        let tip = NSLocalizedString("Click to save tok bootstrap node", comment: "")
        let shareLink = "tok://bootstrap?server=\(result.server)&port=\(result.port)&protocol=\(networkProtocolCell.networkProtocol.rawValue)&publicKey=\(result.publicKey)\n\(tip)"
        share(text: shareLink, messageService: messageService)
    }
}

extension NodeDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return datasource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datasource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return datasource[indexPath.section][indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 14)
        header.textLabel?.textColor = UIColor("#83838D")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showNetworkProtocols(indexPath: indexPath)
        share(indexPath: indexPath)
    }
}
