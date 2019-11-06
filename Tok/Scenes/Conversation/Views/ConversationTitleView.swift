//
//  ConversationTitleView.swift
//  Tok
//
//  Created by Bryce on 2018/12/16.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class ConversationTitleView: UIView {
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, muteImageView, verifiedImageView])
        stackView.alignment = .center
        stackView.spacing = 3
        stackView.distribution = .equalCentering
        return stackView
    }()
    
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
    
    lazy var muteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatMute")
        return imageView
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
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
    
    func update(title: String, subtitle: String, userStatus: UserStatus, muted: Bool, verified: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        userStatusView.userStatus = userStatus
        muteImageView.isHidden = !muted
        verifiedImageView.isHidden = !verified
    }
    
    private func setupViews() {        
        addSubview(stackView)
        addSubview(subtitleLabel)
        addSubview(userStatusView)
        
        muteImageView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        verifiedImageView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        stackView.snp.makeConstraints { (make) in
            make.top.equalTo(6)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(20)
        }
        
        subtitleLabel.snp.makeConstraints { (make) in
            make.top.equalTo(stackView.snp.bottom)
            make.centerX.equalToSuperview()
            make.height.equalTo(18)
            make.bottom.equalToSuperview()
        }
        
        userStatusView.snp.makeConstraints { (make) in
            make.trailing.equalTo(subtitleLabel.snp.leading).offset(-3)
            make.size.equalTo(CGSize(width: 6, height: 6))
            make.centerY.equalTo(subtitleLabel)
        }
    }
}
