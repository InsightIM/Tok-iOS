//
//  NetworkSettingViewController.swift
//  Tok
//
//  Created by Bryce on 2019/9/28.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Action

class AddItemCell: UITableViewCell {
    lazy var leftImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "BlueAdd")
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokLink
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(leftImageView)
        leftImageView.snp.makeConstraints { (make) in
            make.size.equalTo(20)
            make.left.equalTo(20)
            make.centerY.equalToSuperview()
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(leftImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingItemCell: UITableViewCell {
    lazy var checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var topLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokTitle4
        return label
    }()
    
    lazy var middleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokTitle4
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    lazy var bottomLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokTitle4
        return label
    }()
    
//    lazy var webView: WKWebView = {
//        let webView = WKWebView()
//        return webView
//
////        WebViewController
//    }()
    
//    lazy var shareButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.frame = CGRect(origin: .zero, size: CGSize(width: 60, height: 44))
//        button.setTitle(NSLocalizedString("Share", comment: ""), for: .normal)
//        if #available(iOS 11.0, *) {
//            button.contentHorizontalAlignment = .trailing
//        } else {
//            button.contentHorizontalAlignment = .right
//        }
//        return button
//    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .detailButton
        
        contentView.addSubview(checkmarkImageView)
        contentView.addSubview(topLabel)
        contentView.addSubview(middleLabel)
        contentView.addSubview(bottomLabel)
        
        checkmarkImageView.snp.makeConstraints { (make) in
            make.size.equalTo(24)
            make.leading.equalTo(20)
            make.centerY.equalToSuperview()
        }
        
        topLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(checkmarkImageView.snp.trailing).offset(6)
            make.top.equalTo(10)
            make.trailing.equalTo(-10)
        }
        
        middleLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(topLabel)
            make.top.equalTo(topLabel.snp.bottom)
            make.trailing.equalTo(-10)
        }
        
        bottomLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(topLabel)
            make.top.equalTo(middleLabel.snp.bottom)
            make.trailing.equalTo(-10)
            make.bottom.equalTo(-10)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindData(model: NetworkSettingViewController.SettingItem, tox: OCTTox) {
        topLabel.text = model.title
        middleLabel.text = model.detailTitle
        bottomLabel.text = model.connectionState
        if case .proxy = model.type {
            canSelected = true
            showCheckmark = model.selected
        } else {
            canSelected = false
        }
        checkConnectionState(item: model, tox: tox)
    }
    
    var showCheckmark: Bool = false {
        didSet {
            checkmarkImageView.image = showCheckmark ? UIImage(named: "Checkmark") : nil
        }
    }
    
    var canSelected: Bool = true {
        didSet {
            if canSelected {
                checkmarkImageView.snp.updateConstraints { (make) in
                    make.size.equalTo(24)
                }
                topLabel.snp.updateConstraints { (make) in
                    make.leading.equalTo(checkmarkImageView.snp.trailing).offset(6)
                }
            } else {
                checkmarkImageView.snp.updateConstraints { (make) in
                    make.size.equalTo(0)
                }
                topLabel.snp.updateConstraints { (make) in
                    make.leading.equalTo(checkmarkImageView.snp.trailing).offset(0)
                }
            }
        }
    }
    
    var available: Bool = false {
        didSet {
            self.bottomLabel.textColor = available
                ? UIColor.tokTitle4
                : UIColor.tokNotice
        }
    }
    
    func checkConnectionState(item: NetworkSettingViewController.SettingItem, tox: OCTTox) {
        self.bottomLabel.text = NSLocalizedString("Connecting", comment: "")
        self.bottomLabel.textColor = .tokFootnote
        
        DispatchQueue.global().async {
            switch item.type {
            case .node(let model):
                guard let model = model else { return }
                let available = OCTTox.checkBootstrapNode(model.server, port: model.port, isTCP: model.networkProtocol == .TCP, publicKey: model.publicKey)
                DispatchQueue.main.async {
                    self.available = available
                    self.bottomLabel.text = available
                        ? NSLocalizedString("Online", comment: "")
                        : NSLocalizedString("Offline", comment: "")
                }
            case .proxy(let model):
                guard let model = model else { return }
                let available = OCTTox.checkSocks5(withHost: model.server, port: model.port)
                
                DispatchQueue.main.async {
                    self.available = available
                    self.bottomLabel.text = available
                        ? NSLocalizedString("Available", comment: "")
                        : NSLocalizedString("Unavailable", comment: "")
                }
            default: break
            }
        }
    }
}

class NetworkSettingViewController: BaseViewController {
    struct SettingItem {
        enum SettingItemStyle {
            case `switch`(on: Bool)
            case add
            case item
        }
        enum ItemType {
            case proxy(model: ProxyModel?)
            case node(model: NodeModel?)
            case udp
        }
        
        let style: SettingItemStyle
        let type: ItemType
        let title: String
        var selected: Bool = false
        var detailTitle: String? = nil
        var connectionState: String? = nil
        let action: CocoaAction?
    }

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 20
//        tableView.sectionFooterHeight = 0.01
        
        let headerView = NetworkSetHeaderView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 224))
        headerView.helpBlock = { [weak self] in
            guard let self = self else {
                return
            }
            let webVC = WebViewController()
            guard let filePath = Bundle.main.path(forResource: "net_set", ofType: "html") else {
                return
            }
            webVC.url = URL(fileURLWithPath: filePath)
            self.navigationController?.pushViewController(webVC, animated: true)
        }
        
        tableView.tableHeaderView = headerView
        tableView.tableFooterView = NetworkSetFooterView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 90))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellType: SwitchCell.self)
        tableView.register(cellType: SettingItemCell.self)
        tableView.register(cellType: AddItemCell.self)
        
        return tableView
    }()
    
    var dataSource: [[SettingItem]] = []
    
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        super.init()
        hidesBottomBarWhenPushed = true
        
        bindData()
    }
    
    func bindData() {
        let userDefaultsManager = UserDefaultsManager()
        
        let proxyModels = ProxyModel.retrieve()
            .map { model -> NetworkSettingViewController.SettingItem in
                let title = "\(model.server):\(model.port)"
                return SettingItem(style: .item, type: .proxy(model: model), title: title, selected: model.selected, detailTitle: nil, connectionState: NSLocalizedString("Connecting", comment: ""), action: nil)
        }
        var proxyItems: [SettingItem] = []
        proxyItems.append(SettingItem(style: .switch(on: userDefaultsManager.proxyEnabled), type: .proxy(model: nil), title: NSLocalizedString("Enable Proxy", comment: ""), action: nil))
        proxyItems.append(contentsOf: proxyModels)
        proxyItems.append(SettingItem(style: .add, type: .proxy(model: nil), title: NSLocalizedString("Add Proxy", comment: ""), action: nil))
        
        let nodeModels = NodeModel.retrieve()
            .map { model -> NetworkSettingViewController.SettingItem in
                let title = "\(model.server):\(model.port)"
                return SettingItem(style: .item, type: .node(model: model), title: title, selected: false, detailTitle: model.publicKey, connectionState: NSLocalizedString("Connecting", comment: ""), action: nil)
        }
        var nodeItems: [SettingItem] = []
        nodeItems.append(SettingItem(style: .switch(on: userDefaultsManager.customBootstrapEnabled), type: .node(model: nil), title: NSLocalizedString("Use Custom Bootstrap Node", comment: ""), action: nil))
        nodeItems.append(contentsOf: nodeModels)
        nodeItems.append(SettingItem(style: .add, type: .node(model: nil), title: NSLocalizedString("Add Bootstrap Node", comment: ""), action: nil))
        
        dataSource = [
            [
                SettingItem(style: .switch(on: userDefaultsManager.UDPEnabled), type: .udp, title: NSLocalizedString("Enable UDP", comment: ""), action: nil),
            ]
        ]
        dataSource.append(proxyItems)
        dataSource.append(nodeItems)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Network Settings", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
}

extension NetworkSettingViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = dataSource[indexPath.section][indexPath.row]
        switch model.style {
        case .switch(let isOn):
            let cell: SwitchCell = tableView.dequeueReusableCell(for: indexPath)
            cell.nameLabel.text = model.title
            cell.switchButton.isOn = isOn
            
            switch model.type {
            case .udp:
                cell.switchButton.rx.isOn
                    .skip(1)
                    .distinctUntilChanged()
                    .subscribe(onNext: { isOn in
                        UserDefaultsManager().UDPEnabled = isOn
                    })
                    .disposed(by: cell.disposeBag)
            case .proxy:
                cell.switchButton.rx.isOn
                    .skip(1)
                    .distinctUntilChanged()
                    .subscribe(onNext: { isOn in
                        UserDefaultsManager().proxyEnabled = isOn
                    })
                    .disposed(by: cell.disposeBag)
            case .node:
                cell.switchButton.rx.isOn
                    .skip(1)
                    .distinctUntilChanged()
                    .subscribe(onNext: { isOn in
                        UserDefaultsManager().customBootstrapEnabled = isOn
                        if isOn, !NodeModel.retrieve().isEmpty {
                            UserService.shared.bootstrap()
                        }
                    })
                    .disposed(by: cell.disposeBag)
            }
            
            return cell
        case .item:
            let cell: SettingItemCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bindData(model: model, tox: messageService.tokManager.tox)
            return cell
        case .add:
            let cell: AddItemCell = tableView.dequeueReusableCell(for: indexPath)
            cell.nameLabel.text = model.title
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        didTapCell(indexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = dataSource[indexPath.section][indexPath.row]
        
        switch item.style {
        case .add:
            didTapCell(indexPath: indexPath)
        case .item:
            switch item.type {
            case .proxy(let model):
                guard let model = model, model.selected == false else { return }
                
                let allModels = ProxyModel.retrieve().map { $0.change(selected: $0 == model) }
                ProxyModel.store(models: allModels)
                
                bindData()
                self.tableView.reloadSections([indexPath.section], with: .none)
            default: break
            }
        default: break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let item = dataSource[indexPath.section][indexPath.row]
        if case .item = item.style {
            return true
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let item = dataSource[indexPath.section][indexPath.row]
        let deleteAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: NSLocalizedString("Delete", comment: "")) { [unowned self] (_, index) in
            switch item.type {
            case .proxy(let model):
                let allModels = ProxyModel.retrieve().filter { $0 != model }
                ProxyModel.store(models: allModels)
                
                self.bindData()
                self.tableView.reloadSections([indexPath.section], with: .none)
            case .node(let model):
                let allModels = NodeModel.retrieve().filter { $0 != model }
                NodeModel.store(models: allModels)
                
                self.bindData()
                self.tableView.reloadSections([indexPath.section], with: .none)
            default: break
            }
        }
        
        deleteAction.backgroundColor = .tokNotice
        return [deleteAction]
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section < dataSource.count - 1 else {
            return nil
        }
        return NSLocalizedString("Change needs restart to take effect.", comment: "")
    }
    
    private func didTapCell(indexPath: IndexPath) {
        let item = dataSource[indexPath.section][indexPath.row]
        switch item.style {
        case .add, .item:
            switch item.type {
            case .proxy(let model):
                let vc = ProxyDetailViewController(messageService: messageService, model: model)
                vc.completion = { [weak self] in
                    self?.bindData()
                    self?.tableView.reloadSections([indexPath.section], with: .none)
                }
                present(UINavigationController(rootViewController: vc), animated: true, completion: nil)
            case .node(let model):
                let vc = NodeDetailViewController(messageService: messageService, model: model)
                vc.completion = { [weak self] in
                    self?.bindData()
                    self?.tableView.reloadSections([indexPath.section], with: .none)
                }
                present(UINavigationController(rootViewController: vc), animated: true, completion: nil)
            default:
                break
            }
        case .switch: break
        }
    }
}
