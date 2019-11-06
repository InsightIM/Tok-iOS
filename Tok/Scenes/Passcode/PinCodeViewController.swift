//
//  PinCodeViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/27.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

enum PinCodeType {
    case setPin
    case changePin
    case openQuickPin
    case closeQuickPin
    case deletePin
    case desPin
    case changeDesPin
    case deleteDesPin
}

class PinCodeViewController: BaseViewController {
    
    struct Constants {
        static let pinLength = 4
    }
    
    var lockBlock: ((_ lock: Bool) -> ())?
    private var type: PinCodeType = .setPin
    private var tempCode = ""
    
    init(useType: PinCodeType) {
        type = useType
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private(set) var oldPinCode = UserDefaultsManager().userPasscode
    private(set) var oldDesPinCode = UserDefaultsManager().userDestroyPasscode
    
    let kMaxRetryCount = 5
    private var retryCount = 0
    private var retryDate: Date?
    private let retryTimeInterval: TimeInterval = 30
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""),
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(PinCodeViewController.cancelAction));
        
        switch type {
        case .setPin:
            title = NSLocalizedString("Set Passcode", comment: "")
            passcodeView.titleLabel.text = NSLocalizedString("Enter Passcode", comment: "")
            oldPinCode = ""
        case .changePin:
            title = NSLocalizedString("Change Passcode", comment: "")
            passcodeView.titleLabel.text = NSLocalizedString("Enter your old Passcode", comment: "")
        case .desPin:
            title = NSLocalizedString("Set Destroy Passcode", comment: "")
            passcodeView.titleLabel.text = NSLocalizedString("Enter Destroy Passcode", comment: "")
            oldDesPinCode = ""
        case .changeDesPin:
            title = NSLocalizedString("Change Destroy Passcode", comment: "")
            passcodeView.titleLabel.text = NSLocalizedString("Enter your old Destroy Passcode", comment: "")
        case .openQuickPin, .closeQuickPin, .deletePin:
            title = NSLocalizedString("Verify Passcode", comment: "")
            passcodeView.titleLabel.text = NSLocalizedString("Enter Passcode", comment: "")
        default:
            title = NSLocalizedString("Verify Destroy Passcode", comment: "")
            passcodeView.titleLabel.text = NSLocalizedString("Enter Destroy Passcode", comment: "")
        }
        
        view.addSubview(passcodeView)
        passcodeView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.topLayoutGuide.snp.bottom).offset(80)
            make.width.equalTo(screenWidth*0.7)
            make.bottom.lessThanOrEqualTo(self.bottomLayoutGuide.snp.top)
        }
        passcodeView.layoutIfNeeded()
        
        deal()
        
        _ = NotificationCenter.default.rx
            .notification(Notification.Name(rawValue: "showKeyboard"))
            .takeUntil(self.rx.deallocated)
            .subscribe(onNext: { _ in
                self.passcodeView.tv.becomeFirstResponder()
            })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var timeInterval: TimeInterval = 0.0
        if type == .changePin || type == .deletePin {
            timeInterval = UserDefaultsManager().passcodeRetryErrorTime
            retryCount = UserDefaultsManager().passcodeRetryErrorCount
        } else if (type == .changeDesPin || type == .deleteDesPin) {
            timeInterval = UserDefaultsManager().destroycodeRetryErrorTime
            retryCount = UserDefaultsManager().destroycodeRetryErrorCount
        }
        
        if timeInterval > 0 {
            retryDate = Date(timeIntervalSince1970: timeInterval)
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // save retry time
        if type == .changePin || type == .deletePin {
            UserDefaultsManager().passcodeRetryErrorTime = retryDate?.timeIntervalSince1970 ?? 0
            UserDefaultsManager().passcodeRetryErrorCount = retryCount
        } else if (type == .changeDesPin || type == .deleteDesPin) {
            UserDefaultsManager().destroycodeRetryErrorTime = retryDate?.timeIntervalSince1970 ?? 0
            UserDefaultsManager().destroycodeRetryErrorCount = retryCount
        }
    }
    
    @objc
    func cancelAction() {
        navigationController?.popViewController(animated: true)
    }
    
    private lazy var passcodeView: PasscodeSetView = {
        let view = PasscodeSetView()
        view.style = .system
        return view
    }()
}

extension PinCodeViewController {
    
    private func deal() {
        
        passcodeView.Result = { [weak self] (passcode) -> Bool in
            guard let self = self else {
                return false
            }
            
            switch self.type {
            case .setPin:
                
                if self.oldPinCode.count == 0 {
                    
                    self.oldPinCode = passcode;
                    self.passcodeView.titleLabel.text = NSLocalizedString("Verify your new Passcode", comment: "")
                    return true;
                } else {
                    
                    if self.oldPinCode == passcode {
                        UserDefaultsManager().userPasscode = passcode
                        ProgressHUD.showTextHUD(withText: NSLocalizedString("Set Passcode Successful", comment: ""), in: self.view, afterDelay: 1) {
                            self.backWithLocked(true)
                        }
                        return true
                    } else {
                        self.oldPinCode = ""
                        self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Passcode", comment: "")
                        ProgressHUD.showTextHUD(withText: NSLocalizedString("Passcode do not match", comment: ""), in: self.view)
                        return false
                    }
                }
            case .openQuickPin:
                
                if self.oldPinCode == passcode {
                    self.backWithLocked(true)
                    return true
                } else {
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Error Passcode", comment: ""), in: self.view)
                    return false
                }
            case .closeQuickPin:
                
                if self.oldPinCode == passcode {
                    self.backWithLocked(false)
                    return true
                } else {
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Error Passcode", comment: ""), in: self.view)
                    return false
                }
            case .deletePin:
                
                if let retryDate = self.retryDate, Date().timeIntervalSince(retryDate) < self.retryTimeInterval {
                    let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                    ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                    return false
                } else if self.oldPinCode == passcode {
                    UserDefaultsManager().userPasscode = ""
                    UserDefaultsManager().userDestroyPasscode = ""
                    UserDefaultsManager().pinEnabled = false
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Close Passcode Successful", comment: ""), in: self.view, afterDelay: 1) {
                        self.backWithLocked(false)
                    }
                    return true
                } else {
                    
                    if let retryDate = self.retryDate {
                        if Date().timeIntervalSince(retryDate) > self.retryTimeInterval {
                            self.retryDate = Date()
                        }
                        
                        let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                        ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                        return false
                    }
                    
                    self.retryCount += 1
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Passcode Error and please re-enter", comment: ""), in: self.view)
                    
                    if self.retryCount == self.kMaxRetryCount {
                        self.retryCount = 0
                        self.retryDate = Date()
                    }
                    return false
                }
            case .changePin:
                
                if self.oldPinCode.count == 0 {
                    
                    self.oldPinCode = passcode
                    self.passcodeView.titleLabel.text = NSLocalizedString("Verify your new Passcode", comment: "")
                    return true
                } else {
                    
                    if self.tempCode == "temp" {
                        
                        if self.oldPinCode == passcode {
                            UserDefaultsManager().userPasscode = passcode
                            ProgressHUD.showTextHUD(withText: NSLocalizedString("Change Passcode Successful", comment: ""), in: self.view, afterDelay: 1) {
                                self.backWithLocked(false)
                            }
                            return true
                        } else {
                            self.oldPinCode = ""
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Passcode", comment: "")
                            ProgressHUD.showTextHUD(withText: NSLocalizedString("Passcode do not match", comment: ""), in: self.view)
                            return false;
                        }
                    } else {
                        
                        if let retryDate = self.retryDate, Date().timeIntervalSince(retryDate) < self.retryTimeInterval {
                            let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                            ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                            return false
                        } else if self.oldPinCode == passcode {
                            self.retryDate = nil
                            self.oldPinCode = ""
                            self.tempCode = "temp"
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Passcode", comment: "")
                            return true
                        } else {
                            
                            if let retryDate = self.retryDate {
                                if Date().timeIntervalSince(retryDate) > self.retryTimeInterval {
                                    self.retryDate = Date()
                                }
                                
                                let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                                ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                                return false
                            }
                            
                            self.retryCount += 1
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter your old Passcode", comment: "")
                            ProgressHUD.showTextHUD(withText: NSLocalizedString("Passcode Error and please re-enter", comment: ""), in: self.view)
                            
                            if self.retryCount == self.kMaxRetryCount {
                                self.retryCount = 0
                                self.retryDate = Date()
                            }
                            
                            return false
                        }
                    }
                }
            case .desPin:
                
                if self.oldDesPinCode.count == 0 {
                    
                    self.oldDesPinCode = passcode;
                    self.passcodeView.titleLabel.text = NSLocalizedString("Verify your new Destroy Passcode", comment: "")
                    return true;
                } else {
                    if self.oldDesPinCode == passcode {
                        if passcode == self.oldPinCode {
                            self.oldDesPinCode = ""
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Destroy Passcode", comment: "")
                            ProgressHUD.showTextHUD(withText: NSLocalizedString("Destroy Passcode can‘t be the same as Passcode", comment: ""), in: self.view)
                            return false
                        } else {
                            // TODO
                            return true
                        }
                    } else {
                        self.oldDesPinCode = ""
                        self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Destroy Passcode", comment: "")
                        ProgressHUD.showTextHUD(withText: NSLocalizedString("Passcode do not match", comment: ""), in: self.view)
                        return false
                    }
                }
            case .changeDesPin:
                
                if self.oldDesPinCode.count == 0 {
                    
                    self.oldDesPinCode = passcode
                    self.passcodeView.titleLabel.text = NSLocalizedString("Verify your new Destroy Passcode", comment: "")
                    return true
                } else {
                    
                    if self.tempCode == "temp" {
                        
                        if self.oldDesPinCode == passcode {
                            
                            if passcode == self.oldPinCode {
                                self.oldDesPinCode = ""
                                self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Destroy Passcode", comment: "")
                                ProgressHUD.showTextHUD(withText: NSLocalizedString("Destroy Passcode can‘t be the same as Passcode", comment: ""), in: self.view)
                                return false;
                            } else {
                                UserDefaultsManager().userDestroyPasscode = passcode
                                ProgressHUD.showTextHUD(withText: NSLocalizedString("Change Destroy Passcode Successful", comment: ""), in: self.view, afterDelay: 1) {
                                    self.backWithLocked(false)
                                }
                                return true
                            }
                        } else {
                            self.oldDesPinCode = ""
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Destroy Passcode", comment: "")
                            ProgressHUD.showTextHUD(withText: NSLocalizedString("Passcode do not match", comment: ""), in: self.view)
                            return false;
                        }
                    } else {
       
                        if let retryDate = self.retryDate, Date().timeIntervalSince(retryDate) < self.retryTimeInterval {
                            let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                            ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                            return false
                        } else if self.oldDesPinCode == passcode {
                            self.retryDate = nil
                            self.oldDesPinCode = ""
                            self.tempCode = "temp"
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter a new Destroy Passcode", comment: "")
                            return true
                        } else {
                            
                            if let retryDate = self.retryDate {
                                if Date().timeIntervalSince(retryDate) > self.retryTimeInterval {
                                    self.retryDate = Date()
                                }
                                let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                                ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                                return false
                            }
                            
                            self.retryCount += 1
                            self.passcodeView.titleLabel.text = NSLocalizedString("Enter your old Destroy Passcode", comment: "")
                            ProgressHUD.showTextHUD(withText: NSLocalizedString("Destroy Passcode Error and please re-enter", comment: ""), in: self.view)
                            if self.retryCount == self.kMaxRetryCount {
                                self.retryCount = 0
                                self.retryDate = Date()
                            }
                            return false
                        }
                    }
                }
            case .deleteDesPin:
                
                if let retryDate = self.retryDate, Date().timeIntervalSince(retryDate) < self.retryTimeInterval {
                    let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                    ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                    return false
                } else if self.oldDesPinCode == passcode {
                    self.retryDate = nil
                    self.oldDesPinCode = ""
                    UserDefaultsManager().userDestroyPasscode = ""
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Close Destroy Passcode Successful", comment: ""), in: self.view, afterDelay: 1) {
                        self.backWithLocked(false)
                    }
                    return true
                } else {
                    if let retryDate = self.retryDate {
                        if Date().timeIntervalSince(retryDate) > self.retryTimeInterval {
                            self.retryDate = Date()
                        }
                        let errorText = String(format: NSLocalizedString("Passcode error, please try again after %d seconds", comment: ""), Int(self.retryTimeInterval))
                        ProgressHUD.showTextHUD(withText: errorText, in: self.view)
                        return false
                    }
                    
                    self.retryCount += 1
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Error Destroy Passcode", comment: ""), in: self.view)
                    if self.retryCount == self.kMaxRetryCount {
                        self.retryCount = 0
                        self.retryDate = Date()
                    }
                    return false
                }
            }
        }
    }
    
    private func backWithLocked(_ lock: Bool) {
        
        if lockBlock != nil {
            lockBlock!(lock)
        }
        self.navigationController?.popViewController(animated: true)
    }
}
