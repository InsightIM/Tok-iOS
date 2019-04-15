//
//  RegisterViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/19.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import TextFieldEffects
import SwiftMessages
import RxSwift
import RxCocoa
import Action

class RegisterViewController: BaseViewController {
    
    let disposeBag = DisposeBag()
    
    var copyURL: URL?
    
    var isImport: Bool {
        return copyURL != nil
    }
    
    lazy var profileTextField: HoshiTextField = {
        let textField = HoshiTextField()
        textField.placeholder = NSLocalizedString("Username", comment: "")
        textField.placeholderLabel.font = UIFont(name: "Lato-Regular", size: 20)
        textField.placeholderFontScale = 0.8
        textField.borderActiveColor = UIColor.black
        textField.borderInactiveColor = UIColor.tokLightGray
        return textField
    }()
    
    lazy var passwordTextField: HoshiTextField = {
        let textField = HoshiTextField()
        textField.isSecureTextEntry = true
        textField.placeholder = NSLocalizedString("Password", comment: "")
        textField.placeholderLabel.font = UIFont(name: "Lato-Regular", size: 20)
        textField.placeholderFontScale = 0.8
        textField.borderActiveColor = UIColor.black
        textField.borderInactiveColor = UIColor.tokLightGray
        return textField
    }()
    
    lazy var pwdTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokBlue
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.text = NSLocalizedString("Password is required to encrypt your data", comment: "")
        label.isHidden = true
        return label
    }()
    
    lazy var warningTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokDarkGray
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.text = NSLocalizedString("Password strength is critical for the security of your Tok profile and data.", comment: "")
        return label
    }()
    
    lazy var repeatPasswordTextField: HoshiTextField = {
        let textField = HoshiTextField()
        textField.isSecureTextEntry = true
        textField.placeholder = NSLocalizedString("Repeat password", comment: "")
        textField.placeholderLabel.font = UIFont(name: "Lato-Regular", size: 20)
        textField.placeholderFontScale = 0.8
        textField.borderActiveColor = UIColor.black
        textField.borderInactiveColor = UIColor.tokLightGray
        return textField
    }()
    
    lazy var registerButton: UIButton = {
        let button = UIButton()
        if isImport {
            button.fcStyle(title: NSLocalizedString("Import Account", comment: ""))
        } else {
            button.fcStyle(title: NSLocalizedString("Create Account", comment: ""))
        }
        return button
    }()
    
    lazy var registerAction: CocoaAction = {
        return CocoaAction(workFactory: { [weak self] in
            guard let profile = self?.profileTextField.text,
                let pwd = self?.passwordTextField.text
                else {
                    return Observable.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Please fill out the information completely", comment: "")]))
            }
            
            let repeatPwd = self?.repeatPasswordTextField.text
            if self?.isImport == false, pwd != repeatPwd {
                return Observable.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Password don't match", comment: "")]))
            }
            
            if UserService.shared.createProfile(profile, copyFromURL: self?.copyURL, password: pwd) {
                return UserService.shared.login(profile: profile, nickname: "Tok User", password: pwd)
            }
            let errorMsg = self?.isImport == true ? NSLocalizedString("Password is wrong or User name already exists", comment: "") : NSLocalizedString("Create account failed", comment: "")
            return Observable.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        })
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(profileTextField)
        profileTextField.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(60)
            make.top.equalTo(self.view.safeArea.top).offset(10)
        }
        
        view.addSubview(passwordTextField)
        passwordTextField.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(60)
            make.top.equalTo(profileTextField.snp.bottom).offset(20)
        }
        
        var topView: UIView = passwordTextField
        if isImport == false {
            view.addSubview(repeatPasswordTextField)
            repeatPasswordTextField.snp.makeConstraints { (make) in
                make.left.equalTo(20)
                make.right.equalTo(-20)
                make.height.equalTo(60)
                make.top.equalTo(passwordTextField.snp.bottom).offset(20)
            }
            
            view.addSubview(pwdTipLabel)
            pwdTipLabel.snp.makeConstraints { (make) in
                make.top.equalTo(passwordTextField.snp.bottom)
                make.left.right.equalTo(passwordTextField)
                make.height.equalTo(40)
            }
            
            view.addSubview(warningTipLabel)
            warningTipLabel.snp.makeConstraints { (make) in
                make.left.equalTo(20)
                make.right.equalTo(-20)
                make.top.equalTo(repeatPasswordTextField.snp.bottom).offset(20)
            }
            
            topView = warningTipLabel
        }
        
        view.addSubview(registerButton)
        registerButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.top.equalTo(topView.snp.bottom).offset(40)
            make.height.equalTo(50)
        }
        
        bindViewModel()
    }
    
    // MARK: - Private
    
    private func bindViewModel() {
        if isImport == false {
            passwordTextField.rx.controlEvent([.editingDidBegin])
                .map { return false }
                .do(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.repeatPasswordTextField.snp.updateConstraints { (make) in
                        make.top.equalTo(self.passwordTextField.snp.bottom).offset(30)
                    }
                })
                .bind(to: pwdTipLabel.rx.isHidden)
                .disposed(by: disposeBag)
            
            passwordTextField.rx.controlEvent([.editingDidEnd])
                .map { return true }
                .do(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.repeatPasswordTextField.snp.updateConstraints { (make) in
                        make.top.equalTo(self.passwordTextField.snp.bottom).offset(20)
                    }
                })
                .bind(to: pwdTipLabel.rx.isHidden)
                .disposed(by: disposeBag)
        }
            
        let enabledIf = self.isImport
            ? Observable.combineLatest(self.profileTextField.rx.text.orEmpty, self.passwordTextField.rx.text.orEmpty) { profile, pwd in
                return profile.isNotEmpty && pwd.isNotEmpty
                }
            : Observable.combineLatest(self.profileTextField.rx.text.orEmpty, self.passwordTextField.rx.text.orEmpty, self.repeatPasswordTextField.rx.text.orEmpty) { profile, pwd, repeatPwd in
                return profile.isNotEmpty && pwd.count > 0 && repeatPwd.count > 0
        }
        enabledIf.bind(to: registerButton.rx.isEnabled).disposed(by: disposeBag)
        
        registerButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.view.endEditing(true)
                
                if self?.isImport == true {
                    self?.registerAction.execute(())
                    return
                }
                
                let message = NSLocalizedString("Tok will not store your password, so we can't help you to retrieve the password if you forgot it, please remember diligently.", comment: "")
                let alert = UIAlertController(title: NSLocalizedString("Notice", comment: ""), message: message, preferredStyle: .alert)
                let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in
                    self?.registerAction.execute(())
                }

                alert.addAction(okAction)
                self?.present(alert, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        registerAction.executing
            .subscribe(onNext: { executing in
                if executing {
                    ProgressHUD.showLoadingHUDInWindow()
                } else {
                    ProgressHUD.hideLoadingHUDInWindow()
                }
            })
            .disposed(by: disposeBag)
        
        registerAction.errors
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
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
}
