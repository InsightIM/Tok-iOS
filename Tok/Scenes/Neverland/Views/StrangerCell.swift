//
//  StrangerCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Reusable

class StrangerCell: UITableViewCell {
    
    var addAction: (() -> Void)?
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.tokTitle4
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor("#555567")
        label.numberOfLines = 2
        return label
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Add", comment: ""), for: .normal)
        button.setTitle(NSLocalizedString("Added", comment: ""), for: .disabled)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setBackgroundImage(UIColor.tokBlue.createImage(), for: .normal)
        button.setBackgroundImage(UIColor.tokBlue.withAlphaComponent(0.6).createImage(), for: .highlighted)
        button.setBackgroundImage(UIColor("#98CCFE").createImage(), for: .disabled)
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(addButton)
        
        avatarImageView.snp.makeConstraints { (make) in
            make.top.leading.equalTo(12)
            make.size.equalTo(40)
        }
        
        addButton.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 50, height: 30))
            make.centerY.equalToSuperview()
            make.trailing.equalTo(-16).priorityRequired()
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.top.equalTo(avatarImageView)
            make.height.equalTo(20)
            make.trailing.equalTo(addButton.snp.leading).offset(-6)
        }
        
        detailLabel.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
        }
        
        layer.masksToBounds = true
        layer.cornerRadius = 6
        backgroundColor = UIColor.white.withAlphaComponent(0.88)
        
        addButton.addTarget(self, action: #selector(self.didClickAdd), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    func didClickAdd() {
        addAction?()
    }
}
