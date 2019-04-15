//
//  ConversationTitleView.swift
//  Tok
//
//  Created by Bryce on 2018/12/16.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class ConversationTitleView: UIView {
    
    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = UIColor.tokBlack
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.sizeToFit()
        
        return titleLabel
    }()
    
    lazy var subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.textColor = .tokDarkGray
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textAlignment = .center
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.sizeToFit()
        
        return subtitleLabel
    }()
    
    lazy var userStatusView: UserStatusView = {
        let view = UserStatusView()
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }
    
    func update(title: String, subtitle: String, userStatus: UserStatus) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        userStatusView.userStatus = userStatus
    }
    
    private func setupViews() {
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(userStatusView)
        
        titleLabel.snp.makeConstraints { (make) in
            make.top.equalTo(6)
            make.left.right.equalToSuperview()
            make.height.equalTo(20)
        }
        
        subtitleLabel.snp.makeConstraints { (make) in
            make.top.equalTo(titleLabel.snp.bottom)
            make.centerX.equalTo(titleLabel)
        }
        
        userStatusView.snp.makeConstraints { (make) in
            make.right.equalTo(subtitleLabel.snp.left).offset(-3)
            make.size.equalTo(CGSize(width: 6, height: 6))
            make.centerY.equalTo(subtitleLabel)
        }
    }
}
