//
//  SingleLineCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class SingleLineCell: UITableViewCell {
    
    lazy var leftImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var rightImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        return label
    }()
    
    lazy var rightLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokDarkGray
        label.textAlignment = .right
        return label
    }()
    
    lazy var badgeView: BadgeView = {
        let badge =  BadgeView()
        badge.insets = CGSize(width: 6, height: 2)
        badge.font = UIFont.systemFont(ofSize: 11)
        badge.textColor = UIColor.white
        badge.badgeColor = UIColor.tokNotice
        return badge
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(leftImageView)
        leftImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 24, height: 24))
            make.left.equalTo(20)
            make.centerY.equalToSuperview()
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(leftImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
        
        contentView.addSubview(rightImageView)
        rightImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 17, height: 17))
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        contentView.addSubview(rightLabel)
        rightLabel.snp.makeConstraints { (make) in
            make.right.equalTo(-35)
            make.centerY.equalToSuperview()
        }
        
        badgeView.isHidden = true
        contentView.addSubview(badgeView)
        badgeView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalTo(nameLabel.snp.right).offset(8)
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
