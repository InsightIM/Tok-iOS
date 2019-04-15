//
//  ChatEmptyView.swift
//  Tok
//
//  Created by Bryce on 2019/1/28.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class ChatEmptyView: UIView {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "ChatEmpty")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var linkTipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Peer-to-peer communication, end-to-end encryption, click for more information >", comment: ""), for: .normal)
        button.setTitleColor(.tokBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .center
        return button
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokFootnote
        label.text = NSLocalizedString("Secure chat, No third party listen in", comment: "")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()
    
    lazy var inviteButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Invite Friend", comment: ""))
        return button
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        button.fcBorderStyle(title: NSLocalizedString("Add Contact", comment: ""))
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.size.equalTo(CGSize(width: 199, height: 179))
            make.centerX.equalToSuperview()
        }
        
        addSubview(linkTipButton)
        linkTipButton.snp.makeConstraints { (make) in
            make.top.equalTo(imageView.snp.bottom).offset(80)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        addSubview(tipLabel)
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(linkTipButton.snp.bottom).offset(8)
            make.left.right.equalTo(linkTipButton)
        }
        
        addSubview(inviteButton)
        inviteButton.snp.makeConstraints { (make) in
            make.top.equalTo(tipLabel.snp.bottom).offset(22)
            make.left.right.equalTo(linkTipButton)
            make.height.equalTo(50)
        }
        
        addSubview(addButton)
        addButton.snp.makeConstraints { (make) in
            make.top.equalTo(inviteButton.snp.bottom).offset(10)
            make.left.right.equalTo(linkTipButton)
            make.height.equalTo(50)
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
