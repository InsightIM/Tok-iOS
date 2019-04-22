//
//  LargePortraitCell.swift
//  Tok
//
//  Created by Bryce on 2019/4/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class LargePortraitCell: UITableViewCell {

    lazy var avatarImageView: AvatarImageView = {
        let imageView = AvatarImageView()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textColor = UIColor.tokBlack
        return label
    }()
    
    lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.tokDarkGray
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
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
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(avatarImageView).offset(14)
            make.height.equalTo(22)
        }
        
        contentView.addSubview(userNameLabel)
        userNameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(nameLabel.snp.bottom).offset(12)
        }
        
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(userNameLabel.snp.bottom).offset(5)
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
