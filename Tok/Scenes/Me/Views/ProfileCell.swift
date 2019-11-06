//
//  ProfileCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/19.
//  Copyright © 2018年 Insight. All rights reserved.
//

import UIKit

class ProfileCell: UITableViewCell {
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        textLabel?.font = UIFont.systemFont(ofSize: 16)
        textLabel?.textColor = UIColor.tokBlack
        
        detailTextLabel?.font = UIFont.systemFont(ofSize: 15)
        
        let indicatorView = UIImageView(frame: CGRect(x: 0, y: 0, width: 19 + 6, height: 19))
        indicatorView.contentMode = .right
        indicatorView.image = UIImage(named: "RightIndicator")
        accessoryView = indicatorView
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 66, height: 66))
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
