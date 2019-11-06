//
//  LargePortraitCell.swift
//  Tok
//
//  Created by Bryce on 2019/4/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class LargePortraitCell: UITableViewCell {

    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
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
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokDarkGray
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokDarkGray
        return label
    }()
    
    lazy var rightImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "QRCode")
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(rightImageView)
        
        avatarImageView.snp.makeConstraints { (make) in
            make.width.equalTo(avatarImageView.snp.height)
            make.top.equalTo(12)
            make.bottom.equalTo(-12)
            make.left.equalTo(20)
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(rightImageView.snp.left).offset(-8)
            make.top.equalTo(avatarImageView)
            make.height.equalTo(20)
        }
        
        userNameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
        }
        
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(nameLabel)
            make.top.equalTo(userNameLabel.snp.bottom).offset(5)
        }
        
        rightImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 17, height: 17))
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
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
