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
    
    lazy var networkSettingsAction = CocoaAction { [weak self] in
        guard let self = self else { return .empty() }
        let vc = NetworkSettingViewController(messageService: self.messageService)
        self.navigationController?.pushViewController(vc, animated: true)
        return .empty()
    }
    
    lazy var groupSettingsAction = CocoaAction { [weak self] in
        let vc = GroupSettingsViewController()
        self?.navigationController?.pushViewController(vc, animated: true)
        return .empty()
    }
    
    lazy var passcodeAction = CocoaAction { [weak self] in
        UserDefaultsManager().newFeatureForPasscode = false
        if let block = self?.clickNewFeatureForPasscode {
            block()
        }
        
        let vc = PasscodeViewController()
        self?.navigationController?.pushViewController(vc, animated: true)
        return .empty()
    }
    
    lazy var exportProfileAction = CocoaAction { [weak self] in
        let title = NSLocalizedString("The ID Profile contains your ID related information and contact list.\nThe contact list and password are fixed at the time of export. If the contact changes, please export a new profile in time.", comment: "")
        AlertViewManager.showMessageSheet(with: title, actions: [
            (NSLocalizedString("Export", comment: ""), UIAlertAction.Style.default, {
                self?.exportProfile()
            })
        ])
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
    
    struct SettingItem {
        let title: String
        let accessoryType: UITableViewCell.AccessoryType
        let detailText: String?
        let action: CocoaAction?
        let accessoryView: UIView?
    }
    var dataSource: [[SettingItem]]!
    
    fileprivate var documentInteractionController: UIDocumentInteractionController?
    
    lazy var autoSwith = UISwitch()
    lazy var crashSwith = UISwitch()
    
    var clickNewFeatureForPasscode: (() -> ())?
    
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
    
    private let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        super.init()
        hidesBottomBarWhenPushed = true
        
        dataSource = [
            [
                SettingItem(title: NSLocalizedString("ID Profile Name", comment: ""), accessoryType: .none, detailText: UserDefaultsManager().lastActiveProfile, action: nil, accessoryView: nil),
                SettingItem(title: NSLocalizedString("Change Password", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: changePasswordAction, accessoryView: nil),
                SettingItem(title: NSLocalizedString("Passcode", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: passcodeAction, accessoryView: nil)
            ],
            [
                SettingItem(title: NSLocalizedString("Network Settings", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: networkSettingsAction, accessoryView: nil),
            ],
            [
                SettingItem(title: NSLocalizedString("Group Setting", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: groupSettingsAction, accessoryView: nil)
            ],
            [
                SettingItem(title: NSLocalizedString("Reset Tok ID", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: resetTokIDAction, accessoryView: nil),
                SettingItem(title: NSLocalizedString("Autodownload Files", comment: ""), accessoryType: .none, detailText: nil, action: nil, accessoryView: autoSwith),
                SettingItem(title: NSLocalizedString("Enable Crash Report", comment: ""), accessoryType: .none, detailText: nil, action: nil, accessoryView: crashSwith),
            ],
            [
                SettingItem(title: NSLocalizedString("Export Profile", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: exportProfileAction, accessoryView: nil),
                SettingItem(title: NSLocalizedString("Delete Profile", comment: ""), accessoryType: .disclosureIndicator, detailText: nil, action: deleteProfileAction, accessoryView: nil),
            ],
            [
                SettingItem(title: NSLocalizedString("Storage Usage", comment: ""), accessoryType: .disclosureIndicator, detailText: cacheSize(), action: clearCacheAction, accessoryView: nil)
            ],
            [
                SettingItem(title: NSLocalizedString("Log Out", comment: ""), accessoryType: .none, detailText: nil, action: logoutAction, accessoryView: nil)
            ]
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
        
        let userDefaultsManager = UserDefaultsManager()
        
        autoSwith.isOn = userDefaultsManager.autodownloadFiles
        autoSwith.rx.isOn
            .skip(1)
            .distinctUntilChanged()
            .subscribe(onNext: { isOn in
                UserDefaultsManager().autodownloadFiles = isOn
            })
            .disposed(by: disposeBag)
        
        crashSwith.isOn = userDefaultsManager.CrashEnabled
        crashSwith.rx.isOn
            .skip(1)
            .distinctUntilChanged()
            .subscribe(onNext: { isOn in
                UserDefaultsManager().CrashEnabled = isOn
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
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
            cell.textLabel?.textColor = UIColor.tokTitle4
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.text = dataSource[indexPath.section][indexPath.row].title
            return cell
        }
        
        let cell: SettingsCell = tableView.dequeueReusableCell(for: indexPath)
        let item = dataSource[indexPath.section][indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.detailText
        cell.accessoryType = item.accessoryType
        cell.accessoryView = item.accessoryView
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dataSource[indexPath.section][indexPath.row].action?.execute(())
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
            documentInteractionController!.name = "\(name).tok"
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
        
        do {
            try FileManager.default.removeItem(atPath: path.appendingFormat("/files"))
            try FileManager.default.removeItem(atPath: path.appendingFormat("/thumbs"))
            UserService.shared.toxMananger!.files.scheduleFilesCleanup()
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
