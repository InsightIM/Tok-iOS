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

class StrengthView: UIView {
    
    enum Strength {
        case none
        case weak
        case good
        case strong
        
        func color() -> UIColor {
            switch self {
            case .none: return .clear
            case .weak: return .tokNotice
            case .good: return UIColor("#EAA832")
            case .strong: return UIColor("#15C146")
            }
        }
        
        func ratio() -> Float {
            switch self {
            case .none: return 0
            case .weak: return 1/3
            case .good: return 2/3
            case .strong: return 1
            }
        }
    }
    
    lazy var indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .tokNotice
        return view
    }()
    
    var strength: Strength = .none {
        didSet {
            indicatorView.backgroundColor = strength.color()
            indicatorView.snp.remakeConstraints { (make) in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(strength.ratio())
            }
            UIView.animate(withDuration: 0.15) {
                self.layoutIfNeeded()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor("#D8D8D8")
        
        addSubview(indicatorView)
        indicatorView.snp.makeConstraints { (make) in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RegisterViewController: BaseViewController {
    
    let disposeBag = DisposeBag()
    
    var copyURL: URL?
    
    var isImport: Bool {
        return copyURL != nil
    }
    
    lazy var profileTextField: HoshiTextField = {
        let textField = HoshiTextField()
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
        textField.placeholder = NSLocalizedString("Password", comment: "")
        textField.placeholderLabel.font = UIFont(name: "Lato-Regular", size: 20)
        textField.placeholderFontScale = 0.8
        textField.borderActiveColor = UIColor.black
        textField.borderInactiveColor = UIColor.tokLightGray
        return textField
    }()
    
    lazy var profileTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokBlue
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.text = NSLocalizedString("Only used locally and visible to yourself, e.g. Home, iPhone.", comment: "")
        label.isHidden = true
        return label
    }()
    
    lazy var strengthView: StrengthView = {
        let view = StrengthView()
        view.isHidden = true
        return view
    }()
    
    lazy var pwdTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokBlue
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.text = NSLocalizedString("Password is required to protect your local ID profile. It can't be reset if you lose it because there is no central servers.", comment: "")
        label.isHidden = true
        return label
    }()
    
    lazy var warningTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokBlue
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.text = NSLocalizedString("Password can't be reset if you lose it, please remember it diligently.", comment: "")
        label.isHidden = true
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
    
    lazy var safeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "Safe")
        return imageView
    }()
    
    lazy var safeTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokBlack
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.text = NSLocalizedString("No phone number or an email address is required.", comment: "")
        return label
    }()
    
    lazy var termsButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.titleLabel?.numberOfLines = 0
        
        let text = NSLocalizedString("Generating ID means that you have read and accept the ", comment: "")
        let attributedText = NSMutableAttributedString(string: text, attributes: [.foregroundColor: UIColor.tokFootnote])
        let moreText = NSAttributedString(string: NSLocalizedString("Terms of Service", comment: "").uppercased(), attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.tokLink])
        attributedText.append(moreText)
        button.setAttributedTitle(attributedText, for: .normal)
        button.addTarget(self, action: #selector(self.showTerms), for: .touchUpInside)
        return button
    }()
    
    lazy var registerButton: UIButton = {
        let button = UIButton()
        if isImport {
            button.fcStyle(title: NSLocalizedString("Import ID Profile", comment: ""))
        } else {
            button.fcStyle(title: NSLocalizedString("Create ID", comment: ""))
        }
        return button
    }()
    
    lazy var registerAction: CocoaAction = {
        return CocoaAction(workFactory: { [weak self] in
            guard let self = self else { return .empty() }
            
            guard let profile = self.profileTextField.text,
                let pwd = self.passwordTextField.text
                else {
                    return Observable.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Please fill out the information completely", comment: "")]))
            }
            
            let repeatPwd = self.repeatPasswordTextField.text
            if self.isImport == false, pwd != repeatPwd {
                return Observable.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Password don't match", comment: "")]))
            }
            
            if UserService.shared.createProfile(profile, copyFromURL: self.copyURL, password: pwd) {
                if self.isImport {
                    return UserService.shared.login(profile: profile, password: pwd)
                } else {
                    self.showCreatingID(profile: profile, password: pwd)
                    return .just(())
                }
            }
            let errorMsg = self.isImport
                ? NSLocalizedString("Password is wrong or User name already exists", comment: "")
                : NSLocalizedString("Create ID profile failed", comment: "")
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
            
            view.addSubview(profileTipLabel)
            profileTipLabel.snp.makeConstraints { (make) in
                make.top.equalTo(profileTextField.snp.bottom)
                make.left.right.equalTo(profileTextField)
                make.height.equalTo(40)
            }
            
            view.addSubview(strengthView)
            strengthView.snp.makeConstraints { (make) in
                make.top.equalTo(passwordTextField.snp.bottom).offset(6)
                make.left.equalTo(passwordTextField)
                make.width.equalTo(140)
                make.height.equalTo(4)
            }
            
            view.addSubview(pwdTipLabel)
            pwdTipLabel.snp.makeConstraints { (make) in
                make.top.equalTo(strengthView.snp.bottom).offset(4)
                make.left.right.equalTo(passwordTextField)
                make.height.equalTo(26)
            }
            
            view.addSubview(warningTipLabel)
            warningTipLabel.snp.makeConstraints { (make) in
                make.left.right.equalTo(repeatPasswordTextField)
                make.top.equalTo(repeatPasswordTextField.snp.bottom).offset(10)
            }
            
            topView = warningTipLabel
        }
        
        view.addSubview(safeImageView)
        view.addSubview(safeTipLabel)
        safeImageView.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.top.equalTo(topView.snp.bottom).offset(20)
            make.size.equalTo(15)
        }
        safeTipLabel.snp.makeConstraints { (make) in
            make.left.equalTo(safeImageView.snp.right).offset(3)
            make.right.equalTo(-20)
            make.top.equalTo(safeImageView)
        }
        
        view.addSubview(registerButton)
        registerButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.top.equalTo(safeTipLabel.snp.bottom).offset(10)
            make.height.equalTo(50)
        }
        
        view.addSubview(termsButton)
        termsButton.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-20)
        }
        
        bindViewModel()
    }
    
    // MARK: - Private
    
    private func bindViewModel() {
        if isImport == false {
            profileTextField.rx.controlEvent([.editingDidBegin])
                .map { return false }
                .do(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.passwordTextField.snp.updateConstraints { (make) in
                        make.top.equalTo(self.profileTextField.snp.bottom).offset(30)
                    }
                })
                .bind(to: profileTipLabel.rx.isHidden)
                .disposed(by: disposeBag)
            
            profileTextField.rx.controlEvent([.editingDidEnd])
                .map { return true }
                .do(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.passwordTextField.snp.updateConstraints { (make) in
                        make.top.equalTo(self.profileTextField.snp.bottom).offset(20)
                    }
                })
                .bind(to: profileTipLabel.rx.isHidden)
                .disposed(by: disposeBag)
            
            let passwordTextFieldBeginEvent = passwordTextField.rx.controlEvent([.editingDidBegin])
                .map { return false }
                .do(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.repeatPasswordTextField.snp.updateConstraints { (make) in
                        make.top.equalTo(self.passwordTextField.snp.bottom).offset(30)
                    }
                })
                
            passwordTextFieldBeginEvent
                .bind(to: pwdTipLabel.rx.isHidden)
                .disposed(by: disposeBag)
            passwordTextFieldBeginEvent
                .bind(to: strengthView.rx.isHidden)
                .disposed(by: disposeBag)
            
           let passwordTextFieldEndEvent = passwordTextField.rx.controlEvent([.editingDidEnd])
                .map { return true }
                .do(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.repeatPasswordTextField.snp.updateConstraints { (make) in
                        make.top.equalTo(self.passwordTextField.snp.bottom).offset(20)
                    }
                })
            
            passwordTextFieldEndEvent
                .bind(to: pwdTipLabel.rx.isHidden)
                .disposed(by: disposeBag)
            passwordTextFieldEndEvent
                .bind(to: strengthView.rx.isHidden)
                .disposed(by: disposeBag)
            
            passwordTextField.rx.text.orEmpty
                .skip(1)
                .map {
                    let count = $0.count
                    if count == 0 {
                        return StrengthView.Strength.none
                    }
                    if count > 0, count < 6 {
                        return StrengthView.Strength.weak
                    }
                    if count >= 6, count < 10 {
                        return StrengthView.Strength.good
                    }
                    return StrengthView.Strength.strong
                }
                .subscribe(onNext: { [weak self] strength in
                    self?.strengthView.strength = strength
                })
                .disposed(by: disposeBag)
            
            Observable.merge(repeatPasswordTextField.rx.controlEvent([.editingDidBegin]).map { false },
                             repeatPasswordTextField.rx.controlEvent([.editingDidEnd]).map { true })
                .bind(to: warningTipLabel.rx.isHidden)
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
                self?.registerAction.execute(())
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
    
    func showCreatingID(profile: String, password: String) {
        let vc = CreatingIDViewController(profile: profile, password: password)
        vc.modalPresentationStyle = .fullScreen
        vc.finishBlock = { [weak self] in
            ProgressHUD.showLoadingHUD(in: self?.view)
            self?.dismiss(animated: false, completion: nil)
        }
        self.present(vc, animated: false, completion: nil)
    }
    
    @objc
    func showTerms() {
        let vc = TermsViewController()
        self.present(vc, animated: true, completion: nil)
    }
}
