//
//  BotPortraitCell.swift
//  Tok
//
//  Created by Bryce on 2019/3/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class BotPortraitCell: UITableViewCell {
    
    lazy var avatarImageView: AvatarImageView = {
        let imageView = AvatarImageView()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = UIColor.tokBlack
        return label
    }()
    
    lazy var descLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.tokDarkGray
        label.text = NSLocalizedString("Powered by TOK", comment: "")
        return label
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        button.setImage(UIImage(named: "BlueAdd"), for: .normal)
        return button
    }()
    
    var added: Bool = true {
        didSet {
            accessoryView = added ? nil : addButton
            accessoryType = added ? .disclosureIndicator : .none
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.size.equalTo(64)
            make.top.equalTo(12)
            make.bottom.equalTo(-12).priorityHigh()
            make.left.equalTo(20)
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.centerY.equalTo(avatarImageView).offset(-10)
        }
        
        contentView.addSubview(descLabel)
        descLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.equalTo(-10)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
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

