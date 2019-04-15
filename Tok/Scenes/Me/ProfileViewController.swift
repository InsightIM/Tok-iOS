//
//  ProfileViewController.swift
//  Tok
//
//  Created by Bryce on 2018/7/19.
//  Copyright © 2018年 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ProfileViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    
    let titles: [[String]] = [
        [NSLocalizedString("Avatar", comment: ""), NSLocalizedString("Nickname", comment: ""), NSLocalizedString("About", comment: "")]
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
        tableView.register(cellType: ProfileCell.self)
        
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("My Profile", comment: "")
        
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

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ProfileCell = tableView.dequeueReusableCell(for: indexPath)
        let title = titles[indexPath.section][indexPath.row]
        cell.textLabel?.text = title
        switch indexPath.row {
        case 0:
            cell.avatarImageView.setImage(with: UserService.shared.toxMananger!.user.userAvatar(), identityNumber: 0, name: UserService.shared.nickName)
        case 1:
            cell.avatarImageView.image = nil
            cell.detailTextLabel?.text = UserService.shared.nickName
        default:
            cell.avatarImageView.image = nil
            cell.detailTextLabel?.text = UserService.shared.statusMessage
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? 88 : 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.row {
        case 0:
            guard let cell = tableView.cellForRow(at: indexPath) as? ProfileCell else {
                return
            }
            
            let image = cell.avatarImageView.image
            let vc = ProfilePhotoViewController(image: image)
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            let alertController = UIAlertController(title: NSLocalizedString("New Name", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField(configurationHandler: { textField in
                textField.text = UserService.shared.nickName ?? "Tok User"
                textField.clearButtonMode = .whileEditing
            })
            
            let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self, weak alertController] _ in
                guard let alertController = alertController, let textField = alertController.textFields?.first else { return }
                
                do {
                    try UserService.shared.toxMananger!.user.setUserName(textField.text)
                    self?.tableView.reloadData()
                } catch let error {
                    ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
                }
            }
            
            alertController.addAction(confirmAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        default:
            let alertController = UIAlertController(title: NSLocalizedString("New About", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField(configurationHandler: { textField in
                textField.text = UserService.shared.statusMessage ?? ""
                textField.clearButtonMode = .whileEditing
            })
            
            let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self, weak alertController] _ in
                guard let alertController = alertController, let textField = alertController.textFields?.first else { return }
                
                do {
                    try UserService.shared.toxMananger!.user.setUserStatusMessage(textField.text)
                    self?.tableView.reloadData()
                } catch let error {
                    ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
                }
            }
            
            alertController.addAction(confirmAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
