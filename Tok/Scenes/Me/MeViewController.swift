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
    
    let titles: [[(String, String, String, Bool)]] = [
        [("Me", "", "", false)],
        [(NSLocalizedString("My Tok ID", comment: ""), "MyID", "QRCode", false), (NSLocalizedString("FindFriendBot", comment: ""), "Bot", "", true)],
        [(NSLocalizedString("Security & Privacy", comment: ""), "SecurityAndPrivacy", "", false), (NSLocalizedString("About Tok", comment: ""), "About", "", false)],
        [(NSLocalizedString("Settings", comment: ""), "Settings", "", false)]
    ]
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 20
        tableView.sectionFooterHeight = 0.01
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(cellType: PortraitCell.self)
        tableView.register(cellType: SingleLineCell.self)
        
        return tableView
    }()
    
    let userDefaultsManager = UserDefaultsManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Me", comment: "")
        largeTitleDisplay = true
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
}

extension MeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: PortraitCell = tableView.dequeueReusableCell(for: indexPath)
            cell.avatarImageView.setImage(with: UserService.shared.toxMananger!.user.userAvatar(), identityNumber: 0, name: UserService.shared.nickName)
            cell.nameLabel.text = UserService.shared.nickName
            cell.userNameLabel.text = NSLocalizedString("Username", comment: "") + ": " + (UserDefaultsManager().lastActiveProfile ?? "")
            cell.detailLabel.text = UserService.shared.statusMessage
            return cell
        } else {
            let cell: SingleLineCell = tableView.dequeueReusableCell(for: indexPath)
            let (title, imageName, rightImageName, checkBotTip) = titles[indexPath.section][indexPath.row]
            cell.leftImageView.image = UIImage(named: imageName)
            cell.nameLabel.text = title
            if rightImageName.isNotEmpty {
                cell.rightImageView.image = UIImage(named: rightImageName)
            }
            if checkBotTip {
                cell.badgeView.isHidden = !userDefaultsManager.showFindFriendBotTip
                cell.badgeView.text = "New"
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 88 : 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            let vc = ProfileViewController()
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            if indexPath.row == 0 {
                let vc = QRViewerController(text: UserService.shared.toxMananger!.user.userAddress)
                navigationController?.pushViewController(vc, animated: true)
            } else { // bot
                let vc = BotInfoViewController()
                navigationController?.pushViewController(vc, animated: true)
            }
        case 2:
            if indexPath.row == 0 {
                presentPrivacy()
            } else { // About
                let vc = AboutViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            }
        default:
            let vc = SettingsViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
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
