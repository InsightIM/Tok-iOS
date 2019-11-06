//
//  PasscodeLockView.swift
//  Tok
//
//  Created by lbowen on 2019/9/27.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift

class PasscodeLockView: UIView {
    
    private let disposeBag = DisposeBag()
    private var errCount = 5

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setUpSubviews()
        deal()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpSubviews() {
        
        self.alpha = 0
        
        self.addSubview(bgView)
        self.addSubview(passcodeView)
        
        bgView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        passcodeView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.equalTo(screenWidth*0.7)
        }
        passcodeView.layoutIfNeeded()
    }
    
    private lazy var bgView: UIImageView = {
        let bg = UIImageView(image: UIImage(named: "LaunchBg"))
        return bg
    }()
    
    private lazy var passcodeView: PasscodeSetView = {
        let view = PasscodeSetView()
        view.style = .custom
        view.titleLabel.text = NSLocalizedString("Enter Passcode", comment: "")
        return view
    }()
}

extension PasscodeLockView {
    
    private func deal() {
        passcodeView.Result = { [weak self] (passcode) -> Bool in
            guard let self = self else { return false }
            let oldCode = UserDefaultsManager().userPasscode
            let oldDesCode = UserDefaultsManager().userDestroyPasscode
            
            if oldCode == passcode || passcode == "TouchOrFaceId" {

                UserDefaultsManager().passcodeRetryErrorCount = 0
                UserDefaultsManager().passcodeRetryErrorTime = 0

                self.closeLock()
                return true
            } else if oldDesCode == passcode {
                
                UserDefaultsManager().destroycodeRetryErrorCount = 0
                UserDefaultsManager().destroycodeRetryErrorTime = 0
                
                do {
                    UserService.shared.toxMananger?.managerGetTox()?.stop()
                    try UserService.shared.deleteProfile(withLogout: false)
                    let profile = "Tok \(Int(arc4random() % 9999))"
                    let password = "pwd"
                    if UserService.shared.createProfile(profile, copyFromURL: nil, password: password) {
                        UserService.shared.login(profile: profile, password: password)
                            .subscribe(onNext: { [weak self] in
                                _ = try? UserService.shared.toxMananger?.user.setUserName(profile)
                                self?.closeLock()
                            })
                            .disposed(by: self.disposeBag)
                    }
                } catch {
                    UserService.shared.logout()
                }
                
//                ProgressHUD.showTextHUD(withText: NSLocalizedString("Enter the Destroy Passcode and Tok log out", comment: ""), in: weakSelf, afterDelay: 1) {
//                    weakSelf?.closeLock()
//                }
                return true
            } else {
                self.passcodeView.titleLabel.alpha = 0
                
                self.errCount -= 1
                if self.errCount > 0 {
                    switch self.errCount {
                    case 4:
                        self.passcodeView.tipLabel.text = NSLocalizedString("You have 4 attempts left before Tok log out", comment: "")
                    case 3:
                        self.passcodeView.tipLabel.text = NSLocalizedString("You have 3 attempts left before Tok log out", comment: "")
                    case 2:
                        self.passcodeView.tipLabel.text = NSLocalizedString("You have 2 attempts left before Tok log out", comment: "")
                    case 1:
                        self.passcodeView.tipLabel.text = NSLocalizedString("You have 1 attempts left before Tok log out", comment: "")
                    default:
                        self.passcodeView.tipLabel.text = nil
                    }
                } else {
                    self.passcodeView.tipLabel.text = NSLocalizedString("Error 5 times and Tok log out", comment: "")
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Error 5 times and Tok log out", comment: ""), in: self, afterDelay: 1) {
                        UserService.shared.logout()
                        UserDefaultsManager().pinEnabled = false
                        self.closeLock()
                    }
                }
                return false
            }
        }
    }
    
    private func closeLock() {
        UIView.animate(withDuration: 0.5, animations: {
            self.alpha = 0
        }) { (finish) in
            self.removeFromSuperview()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showKeyboard"), object: nil)
        }
    }
    
    func showFingerprintTouch() {
        
        self.alpha = 1
        
        let quickLock = UserDefaultsManager().quickUnlockEnabled
        if quickLock == true {
            
            passcodeView.showFingerprintTouch()
        }
    }
}
