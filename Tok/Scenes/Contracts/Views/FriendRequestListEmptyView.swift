//
//  FriendRequestListEmptyView.swift
//  Tok
//
//  Created by Bryce on 2019/7/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class FriendRequestListEmptyView: UIView {

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "FriendRequestListEmpty")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokFootnote
        label.text = NSLocalizedString("No request", comment: "")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.size.equalTo(122)
            make.centerX.equalToSuperview()
        }
        
        addSubview(tipLabel)
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.bottom.equalTo(-80)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
