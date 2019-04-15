//
//  AddFriendViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

class AddFriendViewController: BaseViewController {
    
    let disposeBag = DisposeBag()
    
    private(set) var userAddress: String
    
    private let manager: OCTManager
    private let submanagerFriends: OCTSubmanagerFriends
    
    private let isAddBot: Bool
    init(isAddBot: Bool = false) {
        self.isAddBot = isAddBot
        
        self.manager = UserService.shared.toxMananger!
        self.submanagerFriends = manager.friends
        
        self.userAddress = manager.user.userAddress
        
        super.init()
        
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var textView: UITextView = {
        let textView = RSKPlaceholderTextView()
        textView.placeholder = NSLocalizedString("Please paste your friend's Tok ID", comment: "") as NSString
        textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.black
        textView.backgroundColor = .clear
        textView.returnKeyType = .done
        textView.layer.cornerRadius = 5.0
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.tokLightGray.cgColor
        textView.layer.masksToBounds = true
        return textView
    }()
    
    lazy var scanButton = UIBarButtonItem(title: NSLocalizedString("Scan", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(AddFriendViewController.scanButtonClick))
    
    lazy var pasteButton: UIButton = {
        let button = UIButton()
        button.fcBorderStyle(title: NSLocalizedString("Paste", comment: ""))
        return button
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Send", comment: ""))
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = isAddBot ? NSLocalizedString("Add Bot", comment: "") :  NSLocalizedString("Add Contact", comment: "")
        
        navigationItem.rightBarButtonItem = scanButton
        
        view.addSubview(textView)
        textView.snp.makeConstraints { (make) in
            make.top.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(100)
        }
        
        view.addSubview(addButton)
        if let string = UIPasteboard.general.string, let address = string.matchAddressString() {
            view.addSubview(pasteButton)
            addButton.snp.makeConstraints { (make) in
                make.top.equalTo(textView.snp.bottom).offset(40)
                make.right.equalTo(-20)
                make.height.equalTo(50)
                make.width.equalTo(pasteButton).multipliedBy(2)
            }
            
            pasteButton.snp.makeConstraints { (make) in
                make.top.height.equalTo(addButton)
                make.left.equalTo(20)
                make.right.equalTo(addButton.snp.left).offset(-10)
            }
            
            pasteButton.rx
                .tap
                .subscribe(onNext: { [weak self] _ in
                    self?.textView.text = address
                })
                .disposed(by: disposeBag)
        } else {
            addButton.snp.makeConstraints { (make) in
                make.top.equalTo(textView.snp.bottom).offset(40)
                make.left.equalTo(20)
                make.right.equalTo(-20)
                make.height.equalTo(50)
            }
        }
        
        addButton.rx
            .tap
            .subscribe(onNext: { [weak self] _ in
                guard let `self` = self,
                    let address = self.textView.text,
                    !address.isEmpty else {
                        return
                }
                
                let alertController = UIAlertController(title: NSLocalizedString("Confirm to send friend request", comment: ""), message: "", preferredStyle: .alert)
                alertController.addTextField(configurationHandler: { textField in
                    textField.text = String(format: NSLocalizedString("Hi, i'm %@", comment: ""), UserService.shared.nickName ?? "Tok User")
                    textField.clearButtonMode = .whileEditing
                })
                
                let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak alertController] _ in
                    guard let alertController = alertController, let textField = alertController.textFields?.first else { return }
                    
                    self.sendRequest(address: address, message: textField.text ?? "")
                }

                alertController.addAction(confirmAction)
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                alertController.addAction(cancelAction)
                self.present(alertController, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
    
    func didScanHander(_ code: String) {
        if let result = code.matchAddressString() {
            textView.text = result
        } else {
            alertError()
        }
    }
    
    func alertError(message: String = NSLocalizedString("Wrong ID. It should contain Tok ID", comment: "")) {
        AlertViewManager.showMessageSheet(with: message, cancelTitle: NSLocalizedString("OK", comment: ""))
    }
    
    func sendRequest(address: String, message: String) {
        view.endEditing(true)
        
        FriendService.sendRequest(address: address, message: message)
            .subscribe(onNext: { [weak self] _ in
                self?.textView.text = ""
                self?.navigationController?.popViewController(animated: true)
            }, onError: { [weak self] error in
                self?.alertError(message: error.localizedDescription)
            })
            .disposed(by: self.disposeBag)
    }
    
    @objc func scanButtonClick() {
        let scanner = QRScannerController()
        scanner.didScanStringsBlock = { [unowned self] in
            self.didScanHander($0)
        }
        navigationController?.pushViewController(scanner, animated: true)
    }
}
