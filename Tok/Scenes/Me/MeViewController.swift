//
//  MeViewController.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SafariServices

class MeViewController: BaseViewController {
    
    struct MenuItem {
        enum Style {
            case largePortrait
            case normal
        }
        
        let style: Style
        let title: String
        let leftIcon: String
        let rightIcon: String
        let newFeature: Bool
        let action: (() -> Void)?
    }
    
    var dataSource: [[MenuItem]] = []
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 15
        tableView.sectionFooterHeight = 0.01
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(cellType: LargePortraitCell.self)
        tableView.register(cellType: SingleLineCell.self)
        
        return tableView
    }()
    
    lazy var versionCode: Int = {
        if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let versions = versionString.components(separatedBy: ".")
            let scales = [10000, 100, 1]
            var vCode = 0
            for i in 0 ..< scales.count {
                if i < versions.count, let v = Int(versions[i]) {
                    vCode = vCode + v * scales[i]
                }
            }
            return vCode
        }
        return 0
    }()
    
    private let userDefaultsManager = UserDefaultsManager()
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Me", comment: "")
        largeTitleDisplay = false
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        bindData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bindData()
        tableView.reloadData()
    }
    
    func checkVersion() -> Bool {
        if self.versionCode < UserDefaultsManager().checkUpdateVersionCode {
            return true
        }
        return false
    }
    
    func bindData() {

        let items = [
            [MenuItem(style: .largePortrait, title: "Me", leftIcon: "", rightIcon: "", newFeature: false, action: { [unowned self] in
                let vc = ProfileViewController(messageService: self.messageService)
                vc.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(vc, animated: true)
            })],
            [
                MenuItem(style: .normal, title: NSLocalizedString("Neverland", comment: ""), leftIcon: "Neverland", rightIcon: "NeverlandTip", newFeature: false, action: { [unowned self] in
                    let vc = NeverlandViewController(messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                }),
                MenuItem(style: .normal, title: NSLocalizedString("My Tok ID", comment: ""), leftIcon: "MyID", rightIcon: "", newFeature: false, action: { [unowned self] in
                    let vc = QRViewerController(messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                })
            ],
            [
                MenuItem(style: .normal, title: NSLocalizedString("Wallet", comment: ""), leftIcon: "Wallet", rightIcon: "", newFeature: userDefaultsManager.newFeatureForWallet, action: { [unowned self] in
                    if self.userDefaultsManager.newFeatureForWallet {
                        self.userDefaultsManager.newFeatureForWallet = false
                    }
                    let vc = WalletViewController()
                    self.navigationController?.pushViewController(vc, animated: true)
                })
            ],
            [
                MenuItem(style: .normal, title: NSLocalizedString("Invite to Tok", comment: ""), leftIcon: "Share", rightIcon: "", newFeature: false, action: { [unowned self] in
                    self.presentInvite(messageService: self.messageService)
                }),
                MenuItem(style: .normal, title: NSLocalizedString("About Tok", comment: ""), leftIcon: "About", rightIcon: "", newFeature: checkVersion(), action: { [unowned self] in
                    let vc = AboutViewController(messageService: self.messageService)
                    vc.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(vc, animated: true)
                })
            ],
            [
                MenuItem(style: .normal, title: NSLocalizedString("Settings", comment: ""), leftIcon: "Settings", rightIcon: "", newFeature: false, action: { [unowned self] in
                    let vc = SettingsViewController(messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                })
            ]
        ]
        
        dataSource = items
    }
}

extension MeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let menu = dataSource[indexPath.section][indexPath.row]
        switch menu.style {
        case .largePortrait:
            let cell: LargePortraitCell = tableView.dequeueReusableCell(for: indexPath)
            cell.avatarImageView.image = AvatarManager.shared.userAvatar(messageService: messageService)
            cell.nameLabel.text = UserService.shared.nickName
            cell.userNameLabel.text = NSLocalizedString("Tok ID", comment: "") + ": " + (UserService.shared.toxMananger?.user.userAddress.prefix(8).appending("...") ?? "")
            cell.detailLabel.text = NSLocalizedString("ID Profile Name", comment: "") + ": " + (userDefaultsManager.lastActiveProfile ?? "")
            return cell
        case .normal:
            let cell: SingleLineCell = tableView.dequeueReusableCell(for: indexPath)
            cell.leftImageView.image = UIImage(named: menu.leftIcon)
            cell.nameLabel.text = menu.title
            if menu.rightIcon.isNotEmpty {
                cell.rightImageView.image = UIImage(named: menu.rightIcon)
            }
            if menu.newFeature {
                cell.badgeView.isHidden = !menu.newFeature
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 90 : 44
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        return tableView.sectionHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dataSource[indexPath.section][indexPath.row].action?()
    }
}

extension MeViewController {
    static func pngDataFromImage(_ image: UIImage) throws -> Data {
        var imageSize = image.size
        
        // Maximum png size will be (4 * width * height)
        // * 1.5 to get as big avatar size as possible
        while OCTToxFileSize(4 * imageSize.width * imageSize.height) > OCTToxFileSize(1.5 * Double(kOCTManagerMaxAvatarSize)) {
            imageSize.width *= 0.9
            imageSize.height *= 0.9
        }
        
        imageSize.width = ceil(imageSize.width)
        imageSize.height = ceil(imageSize.height)
        
        var data: Data
        var tempImage = image
        
        repeat {
            UIGraphicsBeginImageContext(imageSize)
            tempImage.draw(in: CGRect(origin: CGPoint.zero, size: imageSize))
            tempImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            guard let theData = tempImage.pngData() else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Avatar setting failed", comment: "")])
            }
            data = theData
            
            imageSize.width *= 0.9
            imageSize.height *= 0.9
        } while (OCTToxFileSize(data.count) > kOCTManagerMaxAvatarSize)
        
        return data
    }
}
