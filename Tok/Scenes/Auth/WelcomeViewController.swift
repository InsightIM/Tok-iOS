//
//  WelcomeViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/19.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

class WelcomeViewController: BaseViewController {
    let disposeBag = DisposeBag()
    
    lazy var bgImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "LaunchBg")
        return imageView
    }()
    
    lazy var registerButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Create ID", comment: ""), color: .white, titleColor: .tokBlue)
        return button
    }()
    
    lazy var loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.fcBorderStyle(title: NSLocalizedString("Login", comment: ""), color: .white, bgColor: .clear)
        return button
    }()
    
    lazy var importButton: UIButton = {
        let button = UIButton(type: .system)
        let attributedString = NSAttributedString(string: NSLocalizedString("Import your tok profile", comment: ""),
                                                  attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue,
                                                               .foregroundColor: UIColor.white])
        button.setAttributedTitle(attributedString, for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prefersNavigationBarHidden = true
        
        let hideLogin = ProfileManager().allProfileNames.count == 0
        
        view.addSubview(bgImageView)
        bgImageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(importButton)
        importButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.bottom.equalTo(-40)
            make.height.equalTo(40)
        }
        
        if hideLogin {
            view.addSubview(registerButton)
            registerButton.snp.makeConstraints { (make) in
                make.left.equalTo(20)
                make.right.equalTo(-20)
                make.bottom.equalTo(importButton.snp.top).offset(-18)
                make.height.equalTo(50)
            }
        } else {
            view.addSubview(loginButton)
            loginButton.snp.makeConstraints { (make) in
                make.left.equalTo(20)
                make.right.equalTo(-20)
                make.bottom.equalTo(importButton.snp.top).offset(-18)
                make.height.equalTo(50)
            }
            
            view.addSubview(registerButton)
            registerButton.snp.makeConstraints { (make) in
                make.left.equalTo(20)
                make.right.equalTo(-20)
                make.bottom.equalTo(loginButton.snp.top).offset(-18)
                make.height.equalTo(50)
            }
            
            loginButton.rx
                .tap
                .subscribe(onNext: { [weak self] _ in
                    let vc = LoginViewController()
                    self?.navigationController?.pushViewController(vc, animated: true)
                })
                .disposed(by: disposeBag)
        }
        
        let logoLabel = UILabel()
        logoLabel.textColor = UIColor.white
        logoLabel.font = UIFont(name: "Lato-Regular", size: 72)
        logoLabel.text = "Tok"
        logoLabel.textAlignment = .center
        bgImageView.addSubview(logoLabel)
        logoLabel.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(0.6)
        }
        
        registerButton.rx
            .tap
            .subscribe(onNext: { [weak self] _ in
                let vc = RegisterViewController()
                vc.title = NSLocalizedString("Create ID Profile", comment: "")
                self?.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: disposeBag)
        
        importButton.rx
            .tap
            .subscribe(onNext: { _ in
                let title = NSLocalizedString("To import your Tok profile:\n1.Click directly on your file;\n2.Use \"Open In\" menu for the file;\n3.Select \"Copy to Tok\".", comment: "")
                AlertViewManager.showMessageSheet(with: title,
                                                  cancelTitle: NSLocalizedString("OK", comment: ""))
            })
            .disposed(by: disposeBag)
    }
}
