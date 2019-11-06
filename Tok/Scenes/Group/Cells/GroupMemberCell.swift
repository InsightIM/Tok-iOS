//
//  GroupMemberCell.swift
//  FChat
//
//  Created by zhanghanbing on 2018/12/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class GroupMemberCell: UITableViewCell {

    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tokFootnote
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)
        
        avatarImageView.snp.makeConstraints { (make) in
            make.leading.equalTo(GroupedPadding)
            make.centerY.equalToSuperview()
            make.size.equalTo(36)
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        
        detailLabel.snp.makeConstraints { (make) in
            make.leading.greaterThanOrEqualTo(nameLabel.snp.trailing).offset(10)
            make.trailing.equalTo(-GroupedPadding)
            make.centerY.equalToSuperview()
        }
        
        let lineView = UIView()
        lineView.backgroundColor = UIColor.tokLine
        addSubview(lineView)
        lineView.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
