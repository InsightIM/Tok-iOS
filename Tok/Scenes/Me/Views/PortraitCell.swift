//
//  PortraitCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class PortraitCell: UITableViewCell {
    
    lazy var avatarImageView: AvatarImageView = {
        let imageView = AvatarImageView()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokBlack
        return label
    }()
    
    lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor.tokDarkGray
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor.tokDarkGray
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.width.equalTo(avatarImageView.snp.height)
            make.top.equalTo(12)
            make.bottom.equalTo(-12)
            make.left.equalTo(20)
            make.height.equalTo(64)
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(avatarImageView)
            make.height.equalTo(24)
        }
        
        contentView.addSubview(userNameLabel)
        userNameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(nameLabel.snp.bottom).offset(5)
        }
        
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(userNameLabel.snp.bottom).offset(3)
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
