//
//  SetPasswordViewController.swift
//  Tok
//
//  Created by Bryce on 2018/7/22.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class SetPasswordViewController: BaseViewController {
    
    let dataSource: [(String, String, Bool)] = [
        (NSLocalizedString("ID Profile Name", comment: ""), "", false),
        (NSLocalizedString("Original password", comment: ""), NSLocalizedString("Enter original password", comment: ""), true),
        (NSLocalizedString("New password", comment: ""), NSLocalizedString("Enter new password", comment: ""), true),
        (NSLocalizedString("Repeat password", comment: ""), NSLocalizedString("Enter new password again", comment: ""), true)
    ]

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 20
        tableView.sectionFooterHeight = 0.01
        tableView.rowHeight = 50
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(cellType: InputCell.self)
        
        return tableView
    }()
    
    lazy var cancelButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(SetPasswordViewController.cancelClicked))
    
    lazy var doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(SetPasswordViewController.doneClicked))
    
    lazy var idCell = InputCell()
    lazy var oldPasswordCell = InputCell()
    lazy var newPasswordCell = InputCell()
    lazy var confirmPasswordCell = InputCell()
    
    var cells: [InputCell]!
    
    override init() {
        super.init()
        hidesBottomBarWhenPushed = true
        
        cells = [idCell, oldPasswordCell, newPasswordCell, confirmPasswordCell]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Set Password", comment: "")
        
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = doneButton
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func cancelClicked() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func doneClicked() {
        guard validatePasswordFields() else {
            return
        }

        ProgressHUD.showLoadingHUDInWindow()
        
        let oldPassword = oldPasswordCell.rightTextField.text!
        let newPassword = newPasswordCell.rightTextField.text!
        
        DispatchQueue.global(qos: .default).async { [unowned self] in
            let result = UserService.shared.toxMananger!.changeEncryptPassword(newPassword, oldPassword: oldPassword)
            
            if result {
                let keychainManager = KeychainManager()
                if keychainManager.toxPasswordForActiveAccount != nil {
                    keychainManager.toxPasswordForActiveAccount = newPassword
                }
            }
            
            DispatchQueue.main.async { [unowned self] in
                ProgressHUD.hideLoadingHUDInWindow()
                
                if result {
                    self.dismiss(animated: true, completion: nil)
                }
                else {
                    ProgressHUD.showTextHUD(withText:NSLocalizedString("Set Password Failed", comment: ""), in: self.view)
                }
            }
        }
    }
    
    func validatePasswordFields() -> Bool {
        guard let oldText = oldPasswordCell.rightTextField.text, !oldText.isEmpty else {
            ProgressHUD.showTextHUD(withText: NSLocalizedString("Original password is empty", comment: ""), in: self.view)
            return false
        }
        guard let newText = newPasswordCell.rightTextField.text, !newText.isEmpty else {
            ProgressHUD.showTextHUD(withText: NSLocalizedString("New password is empty", comment: ""), in: self.view)
            return false
        }
        
        guard let repeatText = confirmPasswordCell.rightTextField.text, !repeatText.isEmpty else {
            ProgressHUD.showTextHUD(withText: NSLocalizedString("Repeat password is empty", comment: ""), in: self.view)
            return false
        }
        
        guard newText == repeatText else {
            ProgressHUD.showTextHUD(withText: NSLocalizedString("Passwords is not match", comment: ""), in: self.view)
            return false
        }
        
        return true
    }
}

extension SetPasswordViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = cells[indexPath.row]
        cell.nameLabel.text = dataSource[indexPath.row].0
        cell.rightTextField.placeholder = dataSource[indexPath.row].1
        cell.rightTextField.isEnabled = dataSource[indexPath.row].2
        cell.rightTextField.isSecureTextEntry = dataSource[indexPath.row].2
        if indexPath.row == 0 {
            cell.rightTextField.text = UserDefaultsManager().lastActiveProfile
        }
        return cell
    }
}
