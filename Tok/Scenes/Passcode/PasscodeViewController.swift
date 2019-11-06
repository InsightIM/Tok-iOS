//
//  PasscodeViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/27.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class PasscodeViewController: BaseViewController {
    
    lazy var pinSwith: UISwitch = {
        let sw = UISwitch()
        return sw
    }()
    
    lazy var unlockSwith: UISwitch = {
        let sw = UISwitch()
        return sw
    }()
    
    lazy var desSwith: UISwitch = {
        let sw = UISwitch()
        return sw
    }()
    
    lazy var pinSwitchCell: SettingsCell = {
        let cell = SettingsCell()
        cell.selectionStyle = .none
        cell.textLabel?.text = NSLocalizedString("Passcode", comment: "")
        cell.accessoryView = pinSwith
        return cell
    }()
    
    lazy var pinChangeCell: SettingsCell = {
        let cell = SettingsCell()
        cell.selectionStyle = .none
        cell.textLabel?.text = NSLocalizedString("Change Passcode", comment: "")
        cell.accessoryType = .disclosureIndicator
        cell.accessoryView = nil
        return cell
    }()
    
    lazy var touchOrFaceIdCell: SettingsCell = {
        let cell = SettingsCell()
        cell.selectionStyle = .none
        cell.textLabel?.text = NSLocalizedString("Touch Unlock", comment: "")
        cell.accessoryView = unlockSwith
        return cell
    }()
    
//    lazy var desSwitchCell: SettingsCell = {
//        let cell = SettingsCell()
//        cell.selectionStyle = .none
//        cell.textLabel?.text = NSLocalizedString("Destroy Passcode", comment: "")
//        cell.accessoryView = desSwith
//        return cell
//    }()
    
    lazy var desChangeCell: SettingsCell = {
        let cell = SettingsCell()
        cell.selectionStyle = .none
        cell.textLabel?.text = NSLocalizedString("Change Destroy Passcode", comment: "")
        cell.accessoryType = .disclosureIndicator
        cell.accessoryView = nil
        return cell
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
//        tableView.sectionHeaderHeight = 20
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    private func loadPinVC(type: PinCodeType) {
        
        let vc = PinCodeViewController(useType: type)
        
        weak var weakSelf = self
        vc.lockBlock = { (lock) in
            
            switch type {
            case .setPin, .deletePin:
                
                UserDefaultsManager().pinEnabled = lock
            case .desPin, .deleteDesPin:
                
                UserDefaultsManager().destroyPinEnabled = lock
            case .openQuickPin, .closeQuickPin:
                
                UserDefaultsManager().quickUnlockEnabled = lock
            default:
                break
            }
            
            weakSelf?.refreshList()
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    lazy var userDefaultsManager = UserDefaultsManager()
    
    var dataSource: [[SettingsCell]] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Passcode", comment: "")
                
        dataSource.append([pinSwitchCell])
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        pinSwith.addTarget(self, action: #selector(pinSwith(sw:)), for: .valueChanged)
        unlockSwith.addTarget(self, action: #selector(unlockSwith(sw:)), for: .valueChanged)
        desSwith.addTarget(self, action: #selector(desSwith(sw:)), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshList()
    }
    
    private func refreshList() {
        dataSource.removeAll()
        
        let isOn = userDefaultsManager.pinEnabled
        pinSwith.isOn = isOn
        
        if isOn {
            
            let touchOrFace = CheakTouchOrFaceId.isSupport()
            if touchOrFace.isSupport {
                
                unlockSwith.isOn = userDefaultsManager.quickUnlockEnabled
                if touchOrFace.isTouchId == false {
                    touchOrFaceIdCell.textLabel?.text = NSLocalizedString("Face Unlock", comment: "")
                }
                dataSource.append([pinSwitchCell, pinChangeCell, touchOrFaceIdCell])
            } else {
                
                dataSource.append([pinSwitchCell, pinChangeCell])
            }
            
//            let desIsOn = userDefaultsManager.destroyPinEnabled
//            desSwith.isOn = desIsOn
//            
//            if desIsOn {
//                dataSource.append([desSwitchCell, desChangeCell])
//            } else {
//                dataSource.append([desSwitchCell])
//            }
        } else {
            dataSource.append([pinSwitchCell])
            UserDefaultsManager().quickUnlockEnabled = false
            UserDefaultsManager().destroyPinEnabled = false
        }
        
        tableView.reloadData()
    }
}

extension PasscodeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dataSource[indexPath.section][indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if pinSwith.isOn && indexPath.section == 0 && indexPath.row == 1 {
            
            loadPinVC(type: .changePin)
            
        } else if desSwith.isOn && indexPath.section == 1 && indexPath.row == 1 {
            
            loadPinVC(type: .changeDesPin)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && userDefaultsManager.pinEnabled == true {
            return NSLocalizedString("Please remember the password and account login password. When the password is forgotten, you can use the account name and login password to re-enter.", comment: "")
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return NSLocalizedString("Your ID profile will be destroyed if you enter the destroy Passcode", comment: "")
        }
        return nil
    }
}

extension PasscodeViewController {
    
    @objc func pinSwith(sw: UISwitch) {
        
        if sw.isOn {
            
            loadPinVC(type: .setPin)
        }else {
            
            loadPinVC(type: .deletePin)
        }
    }
    
    @objc func unlockSwith(sw: UISwitch) {
        
        if sw.isOn {
            
            loadPinVC(type: .openQuickPin)
        }else {
            
            loadPinVC(type: .closeQuickPin)
        }
    }
    
    @objc func desSwith(sw: UISwitch) {
        
        if sw.isOn {
            
            loadPinVC(type: .desPin)
        } else {
            
            loadPinVC(type: .deleteDesPin)
        }
    }
}
