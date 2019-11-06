//
//  PasscodeSetView.swift
//  Tok
//
//  Created by lbowen on 2019/9/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import LocalAuthentication
import RxSwift

enum PassCodeStyle {
    case system
    case custom
}

class PasscodeSetView: UIView {
    
    var Result: ((_ passcode: String) -> Bool)?
    private var isHideBtn = false
    private var curStyle = PassCodeStyle.system
    private let NumberViewBaseTag = 99
    private lazy var selectNumberArray = Array<PinNumberView>()
    private let infoView = PasscodeInfoView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        _ = NotificationCenter.default.rx
            .notification(UIApplication.willEnterForegroundNotification)
            .takeUntil(self.rx.deallocated)
            .subscribe(onNext: { _ in
                
                if UserDefaultsManager().pinEnabled == true {
                    self.tv.resignFirstResponder()
                }
            })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var hideFingerprintBtn: Bool {
        get {
            return isHideBtn
        }
        set {
            isHideBtn = newValue
            if newValue {
                fingerprintBtn.alpha = 0
            } else {
                fingerprintBtn.alpha = 1
            }
        }
    }
    
    var style: PassCodeStyle {
        get {
            return curStyle
        }
        set {
            curStyle = newValue
            if newValue == .custom {
                initCustomSubviews()
            } else {
                initSystemSubviews()
            }
        }
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        if style == .custom {
            customLayoutUpdate()
        } else {
            systemLayoutUpdate()
        }
    }
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        return label
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .red
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var fingerprintBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.contentMode = .center
        btn.setImage(UIImage(named: "TouchId"), for: .normal)
        btn.setImage(UIImage(named: "TouchIdH"), for: .highlighted)
        btn.addTarget(self, action: #selector(showFingerprintTouch), for: .touchUpInside)
        return btn
    }()
    
    private lazy var deleteBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.contentMode = .center
        btn.setImage(UIImage(named: "CodeDelete"), for: .normal)
        btn.setImage(UIImage(named: "CodeDeleteH"), for: .highlighted)
        btn.addTarget(self, action: #selector(deleteBtnTouch), for: .touchUpInside)
        return btn
    }()
    
    lazy var tv: UITextView = {
        let t = UITextView()
        t.alpha = 0
        t.keyboardType = .numberPad
        return t
    }()
}

extension PasscodeSetView {
    
    private func initCustomSubviews() {
        
        self.addSubview(titleLabel)
        self.addSubview(infoView)
        self.addSubview(tipLabel)
        
        titleLabel.textColor = .white
        infoView.codeStyle = .custom
        
        for i in 0..<10 {
            
            let numberView = PinNumberView()
            numberView.numberText = String(format: "%d", i)
            numberView.tag = i + NumberViewBaseTag
            self.addSubview(numberView)
        }
        
        self.addSubview(fingerprintBtn)
        self.addSubview(deleteBtn)
        
        let touchOrFace = CheakTouchOrFaceId.isSupport()
        if touchOrFace.isSupport {
            
            if UserDefaultsManager().quickUnlockEnabled == true {
                hideFingerprintBtn = false
                if touchOrFace.isTouchId == false {
                    fingerprintBtn.setImage(UIImage(named: "FaceId"), for: .normal)
                    fingerprintBtn.setImage(UIImage(named: "FaceIdH"), for: .highlighted)
                }
            } else {
                hideFingerprintBtn = true
            }
        } else {
            
            hideFingerprintBtn = true
        }
    }
    
    private func customLayoutUpdate() {
        
        let superViewW = self.frame.size.width;
        
        titleLabel.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
        }
        
        infoView.snp.makeConstraints { (make) in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(30)
        }
        
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(infoView.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview()
        }
        
        let marginTop: CGFloat = 120
        let margin: CGFloat = 24.0
        let rows = 4
        let columns = 3
        
        let numberWH = (superViewW - margin * CGFloat(columns - 1)) / CGFloat(columns)
        
        for i in 1..<(columns * rows + 1) {
            
            let currentRow = (i-1) / columns
            let currentColumn = (i-1) % columns
            
            let numberX = (margin + numberWH) * CGFloat(currentColumn)
            let numberY = marginTop + (margin + numberWH) * CGFloat(currentRow);
            
            if (i == 10) {
                
                fingerprintBtn.snp.makeConstraints { (make) in
                    make.top.equalToSuperview().offset(numberY)
                    make.leading.equalToSuperview().offset(numberX)
                    make.width.height.equalTo(numberWH)
                }
                continue
            } else if (i == 11) {
                
                let numberView = self.viewWithTag(NumberViewBaseTag)
                numberView?.snp.makeConstraints { (make) in
                    make.top.equalToSuperview().offset(numberY)
                    make.leading.equalToSuperview().offset(numberX)
                    make.width.height.equalTo(numberWH)
                    make.bottom.equalToSuperview()
                }
                continue
            } else if (i == 12) {
                
                deleteBtn.snp.makeConstraints { (make) in
                    make.top.equalToSuperview().offset(numberY)
                    make.leading.equalToSuperview().offset(numberX)
                    make.width.height.equalTo(numberWH)
                }
                continue
            }
            
            let numberView = self.viewWithTag(i+NumberViewBaseTag)
            numberView?.snp.makeConstraints { (make) in
                make.top.equalToSuperview().offset(numberY)
                make.leading.equalToSuperview().offset(numberX)
                make.width.height.equalTo(numberWH)
            }
        }
    }
}

extension PasscodeSetView: UITextViewDelegate {
    
    private func initSystemSubviews() {
        
        self.addSubview(titleLabel)
        self.addSubview(tv)
        self.addSubview(infoView)
        self.addSubview(tipLabel)
        
        titleLabel.textColor = .black
        infoView.codeStyle = .system
        
        tv.delegate = self
        tv.becomeFirstResponder()
    }
    
    private func systemLayoutUpdate() {
        
        titleLabel.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
        }
        
        infoView.snp.makeConstraints { (make) in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(30)
        }
        
        tv.snp.makeConstraints { (make) in
            make.top.leading.bottom.trailing.equalTo(infoView)
        }
        
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(infoView.snp.bottom).offset(15)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        let count = textView.text?.count ?? 0
        
        if count < 5 {
            infoView.infoCount = textView.text?.count ?? 0
            if count == 4 {
                let isRight = Result!(textView.text!)
                if !isRight {
                    
                    animateFailure()
                }
                
                textView.text = nil
                infoView.infoCount = 0
            }
        }
    }
}

extension PasscodeSetView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if style == .custom {
            
            let touch = touches.first
            let touchPoint = (touch?.location(in: self))!
            for i in 0..<10 {
                
                let numberView = self.viewWithTag(i+NumberViewBaseTag) as! PinNumberView
                if numberView.frame.contains(touchPoint) {
                    
                    numberView.viewState = .highlight
                    selectNumberArray.append(numberView)
                }
            }
            
            infoView.infoCount = selectNumberArray.count;
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if style == .custom {
            
            for i in 0..<10 {
                
                let numberView = self.viewWithTag(i+NumberViewBaseTag) as! PinNumberView
                if numberView.viewState == .highlight {
                    
                    numberView.viewState = .normal
                }
            }
            
            if selectNumberArray.count == 4 {
                
                var passcodeStr = ""
                for numberView in selectNumberArray {
                    
                    let codeInt = numberView.tag - NumberViewBaseTag
                    passcodeStr.append(.init(format: "%d", codeInt))
                }
                
                let isRight = Result!(passcodeStr)
                if !isRight {
                    
                    animateFailure()
                }
                
                infoView.infoCount = 0
                selectNumberArray.removeAll()
            }
        }
    }
    
    @objc func showFingerprintTouch() {
        
        let context = LAContext()
        context.localizedCancelTitle = NSLocalizedString("Cancel", comment: "")
        context.localizedFallbackTitle = NSLocalizedString("Enter Passcode", comment: "")
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error:nil) {
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NSLocalizedString("Unlock Tok", comment: "")) { (success, err) in
                
                DispatchQueue.main.async {
                    
                    if (success) {
                        _ = self.Result!("TouchOrFaceId")
                        self.infoView.infoCount = 4
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: NSLocalizedString("Passcode Unlock", comment: "")) { (success, err) in
                
            }
        }
        
        //Error Domain=com.apple.LocalAuthentication Code=-7 "No fingers are enrolled with Touch ID." UserInfo={NSLocalizedDescription=No fingers are enrolled with Touch ID.} //系统没有设置指纹
        //Error Domain=com.apple.LocalAuthentication Code=-3 "Fallback authentication mechanism selected." UserInfo={NSLocalizedDescription=Fallback authentication mechanism selected.}//点击输入密码
        
        //Error Domain=com.apple.LocalAuthentication Code=-1 "Application retry limit exceeded." UserInfo={NSLocalizedDescription=Application retry limit exceeded.}//3次验证失败后报错
        //Error Domain=com.apple.LocalAuthentication Code=-8 "Biometry is locked out." UserInfo={NSLocalizedDescription=Biometry is locked out.}//5次验证都失败后报错
    }
    
    @objc func deleteBtnTouch() {
        
        if selectNumberArray.count > 0 {
            selectNumberArray.removeLast()
        }
        infoView.infoCount = selectNumberArray.count;
    }
}

extension PasscodeSetView {
    
    public func animateFailure(_ completion : (() -> Void)? = nil) {
        
        AudioServicesPlaySystemSound(1521)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock({
            completion?()
        })
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
        animation.duration = 0.6
        animation.values = [-14.0, 14.0, -14.0, 14.0, -8.0, 8.0, -4.0, 4.0, 0.0 ]
        infoView.layer.add(animation, forKey: "shake")
        
        CATransaction.commit()
    }
}
