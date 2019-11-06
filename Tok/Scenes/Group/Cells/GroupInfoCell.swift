//
//  InfoCell.swift
//  FChat
//
//  Created by zhanghanbing on 2018/12/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class GroupInfoCell: UITableViewCell {
    
    lazy var rightImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ShareBlue")?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = UIColor.tokFootnote
        imageView.isHidden = true
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        accessoryType = .disclosureIndicator
        
        textLabel?.font = UIFont.systemFont(ofSize: 16)
        textLabel?.textColor = .tokTitle4
        textLabel?.numberOfLines = 0
        
        detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        detailTextLabel?.textColor = .tokFootnote
        
        contentView.addSubview(rightImageView)
        rightImageView.snp.makeConstraints { (make) in
            make.size.equalTo(14)
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
