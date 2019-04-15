//
//  SettingsViewController.swift
//  Tok
//
//  Created by Bryce on 2018/7/15.
//  Copyright © 2018年 Insight. All rights reserved.
//

import UIKit
import RxSwift
import Action

class SettingsViewController: BaseViewController {
    
    lazy var changePasswordAction = CocoaAction { [weak self] in
        self?.changePassword()
        return .empty()
    }
    
    lazy var resetTokIDAction = CocoaAction { [weak self] in
        self?.resetTokID()
        return .empty()
    }
    
    lazy var exportProfileAction = CocoaAction { [weak self] in
        self?.exportProfile()
        return .empty()
    }
    
    lazy var deleteProfileAction = CocoaAction { [weak self] in
        self?.deleteProfile()
        return .empty()
    }
    
    lazy var clearCacheAction = CocoaAction { [weak self] in
        let message = NSLocalizedString("All files (image, audio and other files) will be deleted forever!\n(Except account profile & database)", comment: "")
        let yes = NSLocalizedString("Confirm", comment: "")
        
        let action: AlertViewManager.Action = {
            self?.clearCache()
            return ()
        }
        
        AlertViewManager.showMessageSheet(with: message, actions: [(yes, .destructive, action)])
        
        return .empty()
    }
    
    lazy var logoutAction = CocoaAction { [weak self] in
        let message = NSLocalizedString("Please make sure you remember the \"User Name\" and \"Password\"", comment: "")
        let yes = NSLocalizedString("Confirm", comment: "")
        let action: AlertViewManager.Action = {
            UserService.shared.logout()
            return ()
        }
        
        AlertViewManager.showMessageSheet(with: message, actions: [(yes, .destructive, action)])
        
        return Observable.empty()
    }
    
    var dataSource: [[(String, CocoaAction?)]]!
    var accessoryTypes: [[UITableViewCell.AccessoryType]]!
    
    fileprivate var documentInteractionController: UIDocumentInteractionController?
    
    lazy var autoSwith = UISwitch()
    
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
        tableView.register(cellType: SettingsCell.self)
        tableView.register(cellType: UITableViewCell.self)
        
        return tableView
    }()
    
    override init() {
        super.init()
        hidesBottomBarWhenPushed = true
        
        dataSource = [
            [(NSLocalizedString("Username", comment: ""), nil), (NSLocalizedString("Change Password", comment: ""), changePasswordAction)],
            [(NSLocalizedString("Reset Tok ID", comment: ""), resetTokIDAction), (NSLocalizedString("Autodownload Files", comment: ""), nil)],
            [(NSLocalizedString("Export Profile", comment: ""), exportProfileAction), (NSLocalizedString("Delete Profile", comment: ""), deleteProfileAction)],
            [(NSLocalizedString("Storage Usage", comment: ""), clearCacheAction)],
            [(NSLocalizedString("Log Out", comment: ""), logoutAction)]
        ]
        
        accessoryTypes = [
            [.none, .disclosureIndicator],
            [.disclosureIndicator, .none],
            [.disclosureIndicator, .disclosureIndicator],
            [.disclosureIndicator],
            [.disclosureIndicator],
            [.none]
        ]
    }
    
    let disposeBag = DisposeBag()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Settings", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        autoSwith.isOn = UserDefaultsManager().autodownloadFiles
        autoSwith.rx.isOn
            .subscribe(onNext: { isOn in
                UserDefaultsManager().autodownloadFiles = isOn
                UserService.shared.setupAutodownload()
            })
            .disposed(by: disposeBag)
    }
    
    fileprivate func cacheSize() -> String {
        guard let profile = UserDefaultsManager().lastActiveProfile else { return "" }
        let path = ProfileManager().pathForProfileWithName(profile)
        let size = folderSizeAtPath(folderPath: path.appendingFormat("/files"))
        return ByteCountFormatter().string(fromByteCount: Int64(size))
    }
    
    private func folderSizeAtPath(folderPath: String) -> UInt64 {
        let manage = FileManager.default
        guard manage.fileExists(atPath: folderPath), let childPath = manage.subpaths(atPath: folderPath) else {
            return 0
        }
        
        var fileSize: UInt64 = 0
        for file in childPath {
            let path = folderPath.appendingFormat("/\(file)")
            fileSize += getFileSize(path: path)
        }
        return fileSize
    }
    
    private func getFileSize(path: String) -> UInt64 {
        let manager = FileManager.default
        var fileSize: UInt64 = 0
        do {
            let dict = try manager.attributesOfItem(atPath: path) as NSDictionary
            fileSize = dict.fileSize()
        } catch {
            dump(error)
        }
        return fileSize
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == dataSource.count - 1 { // Logout
            let cell = tableView.dequeueReusableCell(for: indexPath)
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.text = dataSource[indexPath.section][indexPath.row].0
            return cell
        }
        
        let cell: SettingsCell = tableView.dequeueReusableCell(for: indexPath)
        cell.accessoryType = accessoryTypes[indexPath.section][indexPath.row]
        cell.textLabel?.text = dataSource[indexPath.section][indexPath.row].0
        if indexPath.section == 0, indexPath.row == 0 {
            cell.detailTextLabel?.text = UserDefaultsManager().lastActiveProfile
        } else if indexPath.section == 3, indexPath.row == 0 {
            cell.detailTextLabel?.text = cacheSize()
        } else if indexPath.section == 1, indexPath.row == 1 {
            cell.accessoryView = autoSwith
        } else {
            cell.accessoryView = nil
            cell.detailTextLabel?.text = nil
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dataSource[indexPath.section][indexPath.row].1?.execute(())
    }
}

extension SettingsViewController {
    
    func changePassword() {
        let vc = UINavigationController(rootViewController: SetPasswordViewController())
        present(vc, animated: true, completion: nil)
    }
    
    func resetTokID() {
        let title = NSLocalizedString("Reseting your Tok ID changes your ID permanently. You will keep your current contacts list, but other people won't be able to add you using your old ID.", comment: "")
        let reset = NSLocalizedString("Reset", comment: "")
        let resetAction: AlertViewManager.Action = {
            let newNospam = UInt32.random(in: 0..<UInt32.max)
            UserService.shared.toxMananger!.user.nospam = newNospam
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let address = UserService.shared.toxMananger!.user.userAddress
                AlertViewManager.showMessageSheet(with: NSLocalizedString("Your new Tok ID is", comment: "") + " \(address)", cancelTitle: NSLocalizedString("OK", comment: ""))
            }
        }
        
        AlertViewManager.showMessageSheet(with: title, actions: [(reset, .destructive, resetAction)])
    }
    
    func exportProfile() {
        do {
            let path = try UserService.shared.toxMananger!.exportToxSaveFile()
            
            let name = UserDefaultsManager().lastActiveProfile ?? "profile"
            
            documentInteractionController = UIDocumentInteractionController(url: URL(fileURLWithPath: path))
            documentInteractionController!.delegate = self
            documentInteractionController!.name = "\(name).tox"
            documentInteractionController!.presentOptionsMenu(from: view.frame, in:view, animated: true)
        }
        catch let error as NSError {
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
        }
    }
    
    func deleteProfile() {
        let title = NSLocalizedString("Serious warning: if you delete this file, you will always delete all informations about the current account from this device. consider carefully please !!", comment: "")
        let delete = NSLocalizedString("Delete", comment: "")
        let deleteAction: AlertViewManager.Action = { [weak self] in
            self?.reallyDeleteProfile()
        }
        
        AlertViewManager.showMessageSheet(with: title, actions: [(delete, .destructive, deleteAction)])
    }
    
    func reallyDeleteProfile() {
        let userDefaults = UserDefaultsManager()
        let profileManager = ProfileManager()
        
        let name = userDefaults.lastActiveProfile!
        
        do {
            try profileManager.deleteProfileWithName(name)
            
            KeychainManager().deleteActiveAccountData()
            userDefaults.lastActiveProfile = nil
            
            UserService.shared.logout()
        }
        catch let error as NSError {
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
        }
    }
    
    func clearCache() {
        guard let profile = UserDefaultsManager().lastActiveProfile else { return }
        let path = ProfileManager().pathForProfileWithName(profile)
        
        // TODO: realm delete
//        UserService.shared.toxMananger!.files.removeAllFileMessages()
        do {
            try FileManager.default.removeItem(atPath: path.appendingFormat("/files"))
            try FileManager.default.removeItem(atPath: path.appendingFormat("/thumbs"))
            tableView.reloadData()
        } catch {
        }
    }
}

extension SettingsViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
        return view
    }
    
    func documentInteractionControllerRectForPreview(_ controller: UIDocumentInteractionController) -> CGRect {
        return view.frame
    }
}
