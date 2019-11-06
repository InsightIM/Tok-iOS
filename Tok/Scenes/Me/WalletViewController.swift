//
//  WalletViewController.swift
//  Tok
//
//  Created by Bryce on 2019/10/6.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import SafariServices

class WalletViewController: BaseViewController {
    private let disposeBag = DisposeBag()
    
    private let text: String = "0xa51406f33ac4518d039756b15e85572a51e145a9"
    private let link = "http://etherscan.io/token/0xa51406f33ac4518d039756b15e85572a51e145a9"
    
    lazy var idLabel: UILabel = {
        let label = UILabel()
        label.copyable = true
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.tokBlack
        label.numberOfLines = 0
        return label
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.tokBlack
        label.text = NSLocalizedString("Tokcoin Contract", comment: "")
        return label
    }()
    
    lazy var copyButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Copy", comment: ""), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.setTitleColor(UIColor.tokLink, for: .normal)
        button.setTitleColor(UIColor.tokLink.withAlphaComponent(0.4), for: .highlighted)
        return button
    }()
    
    lazy var descButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.titleLabel?.numberOfLines = 0
        
        let text = NSLocalizedString("View on Etherscan >", comment: "")
        let attributedText = NSMutableAttributedString(string: text, attributes: [.foregroundColor: UIColor.tokLink])
        
        button.setAttributedTitle(attributedText, for: .normal)
        return button
    }()
    
    lazy var commingSoonImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Comming")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var commingSoonLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.tokFootnote
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = NSLocalizedString("The features of wallet are comming soon…", comment: "")
        return label
    }()
    
    override init() {
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Wallet", comment: "")
        view.backgroundColor = UIColor.tokBackgroundColor
        
        createViews()
        idLabel.text = text
        
        copyButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                UIPasteboard.general.string = self.text
            })
            .disposed(by: disposeBag)
        
        descButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                guard let url = URL(string: self.link) else { return }
                let vc = SFSafariViewController(url: url)
                self.present(vc, animated: true)
            })
            .disposed(by: disposeBag)
    }
}

private extension WalletViewController {
    func createViews() {
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(20)
            make.left.equalTo(20)
        }
        
        view.addSubview(copyButton)
        copyButton.snp.makeConstraints { (make) in
            make.right.equalTo(-20)
            make.centerY.equalTo(tipLabel)
        }
        
        let bgView = UIView()
        bgView.layer.borderWidth = 1.0 / UIScreen.main.scale
        bgView.layer.borderColor = UIColor.tokLine.cgColor
        bgView.backgroundColor = UIColor.white
        view.addSubview(bgView)
        bgView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(tipLabel.snp.bottom).offset(8)
        }
        
        bgView.addSubview(idLabel)
        idLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.top.equalTo(15)
            make.bottom.equalTo(-15)
        }
        
        view.addSubview(descButton)
        descButton.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.lessThanOrEqualTo(-20)
            make.top.equalTo(bgView.snp.bottom).offset(10)
        }
        
        view.addSubview(commingSoonImageView)
        commingSoonImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 75, height: 78))
            make.centerX.equalToSuperview()
            make.top.equalTo(descButton.snp.bottom).offset(70)
        }
        
        view.addSubview(commingSoonLabel)
        commingSoonLabel.snp.makeConstraints { (make) in
            make.leading.greaterThanOrEqualTo(20)
            make.trailing.lessThanOrEqualTo(-20)
            make.centerX.equalToSuperview()
            make.top.equalTo(commingSoonImageView.snp.bottom).offset(20)
        }
    }
}
