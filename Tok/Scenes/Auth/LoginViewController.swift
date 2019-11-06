//
//  LoginViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/19.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import TextFieldEffects
import SnapKit
import RxSwift
import Action

class LoginViewController: BaseViewController {
    
    let disposeBag = DisposeBag()
    
    lazy var profileTextField: HoshiTextField = {
        let textField = HoshiTextField()
//        textField.clearButtonMode = .whileEditing
        textField.placeholder = NSLocalizedString("ID Profile Name", comment: "")
        textField.placeholderLabel.font = UIFont(name: "Lato-Regular", size: 20)
        textField.placeholderFontScale = 0.8
        textField.borderActiveColor = UIColor.black
        textField.borderInactiveColor = UIColor.tokLightGray
        return textField
    }()
    
    lazy var passwordTextField: HoshiTextField = {
        let textField = HoshiTextField()
        textField.isSecureTextEntry = true
//        textField.clearButtonMode = .whileEditing
        textField.placeholder = NSLocalizedString("Password", comment: "")
        textField.placeholderLabel.font = UIFont(name: "Lato-Regular", size: 20)
        textField.placeholderFontScale = 0.8
        textField.borderActiveColor = UIColor.black
        textField.borderInactiveColor = UIColor.tokLightGray
        return textField
    }()
    
    lazy var loginButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Login", comment: ""))
        return button
    }()
    
    lazy var loginAction = CocoaAction { [weak self] in
        guard let profile = self?.profileTextField.text,
            let pwd = self?.passwordTextField.text else {
                return Observable.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Please fill out the information completely", comment: "")]))
        }
        
        return UserService.shared.login(profile: profile, password: pwd)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Login", comment: "")

        view.addSubview(profileTextField)
        profileTextField.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(60)
            make.top.equalTo(self.view.safeArea.top).offset(10)
        }
        
        let profileButton = UIButton()
        view.addSubview(profileButton)
        profileButton.snp.makeConstraints { (make) in
            make.edges.equalTo(profileTextField)
        }
        
        view.addSubview(passwordTextField)
        passwordTextField.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(60)
            make.top.equalTo(profileTextField.snp.bottom).offset(20)
        }
        
        view.addSubview(loginButton)
        loginButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.top.equalTo(passwordTextField.snp.bottom).offset(40)
            make.height.equalTo(50)
        }
        
        profileButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.view.endEditing(true)
                
                let items: [(String, UIAlertAction.Style, AlertViewManager.Action?)] =
                    ProfileManager().allProfileNames
                        .map { name in
                            return (name, UIAlertAction.Style.default, {
                                self.profileTextField.text = name
                            })
                }
                
                AlertViewManager.showMessageSheet(with: NSLocalizedString("Choose an Account", comment: ""), actions: items)
            })
            .disposed(by: disposeBag)
        
        bindViewModel()
    }
    
    // MARK: - Private

    private func bindViewModel() {
        loginButton.rx.action = loginAction
        
        loginAction.errors
            .subscribe(onNext: { [weak self] error in
                switch error {
                case .notEnabled:
                    print("")
                case .underlyingError(let error):
                    let err = error as NSError
                    let reason = err.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                    ProgressHUD.showTextHUD(withText: reason ?? error.localizedDescription, in: self?.view)
                }
            })
            .disposed(by: disposeBag)
        
        loginAction.executing
            .subscribe(onNext: { executing in
                if executing {
                    ProgressHUD.showLoadingHUDInWindow()
                } else {
                    ProgressHUD.hideLoadingHUDInWindow()
                }
            })
            .disposed(by: disposeBag)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}
