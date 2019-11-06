//
//  CreatingIDViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/31.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Lottie
import IQKeyboardManagerSwift
import RxSwift
import RxCocoa

class CreatingIDViewController: BaseViewController {
    
    var finishBlock: (() -> Void)?
    
    lazy var hackerView: AnimationView = {
        let view = AnimationView(name: "hacker")
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var creatingTipView = CreatingTipView()
    
    lazy var tokIdLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#C0DBFF")
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    lazy var inputTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#C0DBFF")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.text = NSLocalizedString("Set Your Nickname", comment: "")
        label.isHidden = true
        return label
    }()
    
    lazy var inputField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 15)
        textField.textColor = UIColor("#C0DBFF")
        textField.backgroundColor = UIColor("#002D66")
        textField.layer.cornerRadius = 4
        textField.layer.masksToBounds = true
        textField.isHidden = true
        textField.textAlignment = .center
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    lazy var chatButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Start Secure Chat", comment: ""))
        button.isHidden = true
        button.addTarget(self, action: #selector(self.didClickCreateID), for: .touchUpInside)
        return button
    }()
    
    private let disposeBag = DisposeBag()
    private var toxManager: OCTManager?
    private let tokIdReady = PublishSubject<Bool>()
    private let animationReady = PublishSubject<Bool>()
    init(profile: String, password: String) {
        super.init()
        
        UserService.shared.register(profile: profile, password: password)
            .subscribe(onNext: { [weak self] (toxManager, tokManager) in
                guard let self = self else { return }
                self.toxManager = toxManager
                self.tokIdLabel.text = toxManager.user.userAddress
                self.inputField.text = "Tok \(toxManager.user.userAddress.prefix(4))"
                self.tokIdReady.onNext(true)
                }, onError: { [weak self] error in
                    self?.hackerView.pause()
                    self?.creatingTipView.isHidden = true
                    AlertViewManager.showMessageSheet(with: error.localizedDescription,
                                                      interactive: false,
                                                      cancelTitle: NSLocalizedString("OK", comment: ""),
                                                      customCancelAction: { [weak self] in
                                                        self?.dismiss(animated: true, completion: nil)
                    })
            })
            .disposed(by: disposeBag)
        
        Observable.combineLatest(tokIdReady.asObservable(), animationReady.asObserver()) {
            $0 && $1
            }
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                guard let tokId = self.tokIdLabel.text, tokId.count == Int(kOCTToxAddressLength) else {
                    AlertViewManager.showMessageSheet(with: NSLocalizedString("Something went wrong and try again later", comment: ""),
                                                      interactive: false,
                                                      cancelTitle: NSLocalizedString("OK", comment: ""),
                                                      customCancelAction: { [weak self] in
                                                        self?.dismiss(animated: true, completion: nil)
                    })
                    return
                }
                self.startIDAnimation()
            })
            .disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(hackerView)
        hackerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        creatingTipView.isHidden = true
        view.addSubview(creatingTipView)
        creatingTipView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(1.4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(80)
        }
        
        view.addSubview(tokIdLabel)
        tokIdLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.top.equalTo(creatingTipView.snp.top).offset(50)
        }
        
        view.addSubview(inputTipLabel)
        inputTipLabel.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(creatingTipView.snp.top)
            make.height.equalTo(20)
        }
        
        view.addSubview(inputField)
        inputField.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(creatingTipView.snp.top).offset(40)
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(40)
        }
        
        view.addSubview(chatButton)
        chatButton.snp.makeConstraints { (make) in
            make.top.equalTo(inputField.snp.bottom).offset(58)
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(44)
        }
        
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationController?.interactivePopGestureRecognizer?.delegate = self as? UIGestureRecognizerDelegate
        
        showTime()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        IQKeyboardManager.shared.enable = false
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    private func showTime() {
        hackerView.play()
        self.creatingTipView.finish = { [weak self] in
            self?.animationReady.onNext(true)
        }
        
        creatingTipView.alpha = 0
        creatingTipView.isHidden = false
        UIView.animate(withDuration: 0.2, delay: 3, animations: {
            self.creatingTipView.alpha = 1
        }) { _ in
            self.creatingTipView.start()
        }
    }
    
    func startIDAnimation() {
        let animation = FFStringAppear1by1Animation()
        animation.appearDuration = 0.01
        tokIdLabel.ff_startAnimation(animation) { [weak self] in
            self?.hackerView.pause()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                animation.clear()
                self?.tokIdLabel.removeFromSuperview()
                self?.showNickNameInput()
            }
        }
    }
    
    func showNickNameInput() {
        creatingTipView.isHidden = true
        inputTipLabel.isHidden = false
        
        inputField.alpha = 0
        inputField.isHidden = false
        
        chatButton.alpha = 0
        chatButton.isHidden = false
        UIView.animate(withDuration: 0.5) {
            self.chatButton.alpha = 1
            self.inputField.alpha = 1
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
    
    @objc
    func didClickCreateID() {
        if let nickname = inputField.text, nickname.isNotEmpty {
            _ = try? toxManager?.user.setUserName(nickname)
        }
        
        UserService.shared.didLogin.onNext(())
        finishBlock?()
    }
}

class CreatingTipView: UIView {
    lazy var label1: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#C0DBFF")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.text = NSLocalizedString("Generating ultra-long random ID for you locally", comment: "")
        return label
    }()
    lazy var label2: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#C0DBFF")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.text = NSLocalizedString("No access to personal information", comment: "")
        return label
    }()
    lazy var label3: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#C0DBFF")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.text = NSLocalizedString("No central servers", comment: "")
        return label
    }()
    lazy var label4: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#C0DBFF")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.text = NSLocalizedString("My Tok ID", comment: "")
        label.alpha = 0
        return label
    }()
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [label1, label2, label3, label4])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    private let itemHeight: CGFloat = 20
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label1.heightAnchor.constraint(equalToConstant: itemHeight).isActive = true
        label2.heightAnchor.constraint(equalToConstant: itemHeight).isActive = true
        label3.heightAnchor.constraint(equalToConstant: itemHeight).isActive = true
        label4.heightAnchor.constraint(equalToConstant: itemHeight).isActive = true
        addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var times = 0
    var finish: (() -> Void)?
    func start() {
        guard times < stackView.arrangedSubviews.count - 1 else {
            finish?()
            return
        }
        times += 1
        self.stackView.snp.updateConstraints { (make) in
            make.top.equalTo(-itemHeight * CGFloat(times))
        }
        UIView.animate(withDuration: 0.2, delay: 0.5, animations: {
            self.layoutIfNeeded()
        }) { _ in
            if self.times == self.stackView.arrangedSubviews.count - 1 {
                self.label4.alpha = 1
            }
            self.start()
        }
    }
}
