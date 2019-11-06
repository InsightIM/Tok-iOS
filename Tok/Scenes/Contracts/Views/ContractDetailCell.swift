//
//  InvitationsCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/6.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class ContractDetailCell: UITableViewCell {
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        return label
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.tokFootnote
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.top.equalTo(avatarImageView)
            make.height.equalTo(24)
        }
        
        verifiedImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(verifiedImageView)
        verifiedImageView.snp.makeConstraints { (make) in
            make.left.equalTo(nameLabel.snp.right).offset(0)
            make.right.lessThanOrEqualTo(-10)
            make.centerY.equalTo(nameLabel)
            make.size.equalTo(0)
        }
        
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.right.lessThanOrEqualTo(-10)
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var verified: Bool = false {
        didSet {
            guard verified != oldValue else {
                return
            }
            if verified {
                verifiedImageView.isHidden = false
                verifiedImageView.snp.updateConstraints { (make) in
                    make.left.equalTo(nameLabel.snp.right).offset(3)
                    make.size.equalTo(14)
                }
            } else {
                verifiedImageView.isHidden = true
                verifiedImageView.snp.updateConstraints { (make) in
                    make.left.equalTo(nameLabel.snp.right).offset(0)
                    make.size.equalTo(0)
                }
            }
        }
    }
}
