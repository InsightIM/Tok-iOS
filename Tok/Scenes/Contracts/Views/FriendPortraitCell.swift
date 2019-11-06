//
//  FriendPortraitCell.swift
//  Tok
//
//  Created by Bryce on 2019/8/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class FriendPortraitCell: UITableViewCell {

    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textColor = UIColor.tokBlack
        return label
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var topStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, verifiedImageView])
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokDarkGray
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.top.equalTo(12)
            make.bottom.equalTo(-12).priorityHigh()
            make.leading.equalTo(20)
            make.width.equalTo(64).priorityRequired()
            make.height.equalTo(64)
        }
        
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(topStackView)
        topStackView.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.top.equalTo(avatarImageView).offset(8)
            make.height.equalTo(24)
            make.trailing.lessThanOrEqualTo(-20)
        }
        
        contentView.addSubview(userNameLabel)
        userNameLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.trailing.lessThanOrEqualTo(-20)
            make.top.equalTo(nameLabel.snp.bottom).offset(5)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var verified: Bool = false {
        didSet {
            verifiedImageView.isHidden = !verified
        }
    }
}
