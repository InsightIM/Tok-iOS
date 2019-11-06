//
//  ContactsCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/4.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

class ContractMenuCell: UITableViewCell {
    
    var disposeBag = DisposeBag()
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.black
        return label
    }()
    
    lazy var badgeView: BadgeView = {
        let badge =  BadgeView()
        badge.insets = CGSize(width: 3, height: 3)
        badge.font = UIFont.systemFont(ofSize: 12)
        badge.textColor = UIColor.white
        badge.badgeColor = UIColor.tokNotice
        return badge
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(iconImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
            make.right.equalTo(-80).priority(.low)
        }
        
        badgeView.isHidden = true
        contentView.addSubview(badgeView)
        badgeView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.right.equalTo(-10)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        disposeBag = DisposeBag()
    }

}
