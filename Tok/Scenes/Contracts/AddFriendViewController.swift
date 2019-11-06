//
//  AddFriendViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import IQKeyboardManagerSwift

class AddFriendViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    
    var userAddress: String?
    
    private let manager: OCTManager
    private let submanagerFriends: OCTSubmanagerFriends
    
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        self.manager = messageService.tokManager.toxManager
        self.submanagerFriends = manager.friends
                
        super.init()
        
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tokIdInputCell: TokIdInputCell = {
        let cell = TokIdInputCell()
        return cell
    }()
    
    lazy var setMessageCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Set a Message", comment: "")
        return cell
    }()
    
    lazy var setAliasCell: FriendRequestInputCell = {
        let cell = FriendRequestInputCell()
        cell.nameField.placeholder = NSLocalizedString("Set an Alias (option)", comment: "")
        return cell
    }()
    
    lazy var scanButton = UIBarButtonItem(title: NSLocalizedString("Scan", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(AddFriendViewController.scanButtonClick))
    
    lazy var pasteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Paste", comment: ""), for: .normal)
        button.addTarget(self, action: #selector(self.didClickPaste), for: .touchUpInside)
        return button
    }()
    
    lazy var sendButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Send", comment: ""))
        button.addTarget(self, action: #selector(self.didClickSend), for: .touchUpInside)
        return button
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor("#83838D")
        label.numberOfLines = 0
        label.text = NSLocalizedString("Tok will never scan your address book. Please add friends with Tok ID.", comment: "")
        return label
    }()
    
    lazy var myTokIdButton: UIButton = {
        let button = UIButton(type: .system)
        let title = NSLocalizedString("My Tok ID", comment: "")
        let image = UIImage(named: "QRCode")!
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.set(image: image, title: title, imageSize: image.size, titlePosition: .left, additionalSpacing: 10, state: .normal)
        button.addTarget(self, action: #selector(self.didClickMyTokId), for: .touchUpInside)
        return button
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 180))
        return view
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.estimatedRowHeight = 44
        tableView.sectionHeaderHeight = 40
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = footerView
        
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Add Contact", comment: "")
        
        navigationItem.rightBarButtonItem = scanButton
        
        view.backgroundColor = .tokBackgroundColor
        tableView.backgroundColor = .tokBackgroundColor
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        footerView.addSubview(tipLabel)
        footerView.addSubview(sendButton)
        footerView.addSubview(myTokIdButton)
        tipLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(20).priorityHigh()
            make.trailing.equalTo(-20).priorityHigh()
            make.top.equalTo(10)
        }
        sendButton.snp.makeConstraints { (make) in
            make.leading.equalTo(20).priorityHigh()
            make.trailing.equalTo(-20).priorityHigh()
            make.top.equalTo(tipLabel.snp.bottom).offset(20)
            make.height.equalTo(50)
        }
        myTokIdButton.snp.makeConstraints { (make) in
            make.top.equalTo(sendButton.snp.bottom).offset(40)
            make.leading.greaterThanOrEqualTo(20).priorityHigh()
            make.trailing.lessThanOrEqualTo(-20).priorityHigh()
            make.centerX.equalToSuperview()
        }
        
        pasteButton.isHidden = UIPasteboard.general.string?.matchAddressString() == nil ? true : false
        tokIdInputCell.textView.text = userAddress
        setMessageCell.nameField.text = defaultMessage()
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
    
    func didScanHander(_ code: String) {
        if let result = code.matchAddressString() {
            userAddress = result
            tokIdInputCell.textView.text = userAddress
        } else {
            alertError()
        }
    }
    
    func alertError(message: String = NSLocalizedString("Wrong ID. It should contain Tok ID", comment: "")) {
        AlertViewManager.showMessageSheet(with: message, cancelTitle: NSLocalizedString("OK", comment: ""))
    }
    
    @objc
    func didClickSend() {
        view.endEditing(true)
        guard let address = tokIdInputCell.textView.text else {
            return
        }
        
        let message = setMessageCell.nameField.text ?? defaultMessage()
        let alias = setAliasCell.nameField.text
        let result = messageService.friendService.sendFriendRequest(address: address, message: message, alias: alias)
        switch result {
        case .success:
            self.tokIdInputCell.textView.text = ""
            self.navigationController?.popViewController(animated: true)
        case .failure(let error):
            guard error != .added else {
                let pk = (address as NSString).substring(to: Int(kOCTToxPublicKeyLength))
                if let chat = self.messageService.database.findOrCreateChat(publicKey: pk) {
                    AlertViewManager.showMessageSheet(with: error.localizedDescription, cancelTitle: NSLocalizedString("Start Chatting!", comment: ""), customCancelAction: {
                        NotificationCenter.default.post(name: NSNotification.Name.ShowChat, object: nil, userInfo: ["chat": chat])
                    })
                } else {
                    alertError(message: error.localizedDescription)
                }
                return
            }
            alertError(message: error.localizedDescription)
        }
    }
    
    @objc
    func didClickPaste() {
        tokIdInputCell.textView.text = UIPasteboard.general.string
    }
    
    @objc
    func scanButtonClick() {
        let scanner = QRScannerController(messageService: messageService)
        scanner.didScanStringsBlock = { [unowned self] in
            self.didScanHander($0)
        }
        navigationController?.pushViewController(scanner, animated: true)
    }
    
    @objc
    func didClickMyTokId() {
        let vc = QRViewerController(messageService: messageService)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func defaultMessage() -> String {
        return String(format: NSLocalizedString("Hi, i'm %@", comment: ""), UserService.shared.nickName ?? "Tok User")
    }
}

extension AddFriendViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return tokIdInputCell
        case 1:
            return setMessageCell
        case 2:
            return setAliasCell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Tok ID", comment: "")
        case 1:
            return NSLocalizedString("Message", comment: "")
        case 2:
            return NSLocalizedString("Alias", comment: "")
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 14)
        header.textLabel?.textColor = UIColor("#83838D")
        
        if section == 0 {
            pasteButton.removeFromSuperview()
            header.addSubview(pasteButton)
            pasteButton.snp.makeConstraints { (make) in
                make.trailing.equalTo(-20)
                make.centerY.equalToSuperview()
            }
        }
    }
}
