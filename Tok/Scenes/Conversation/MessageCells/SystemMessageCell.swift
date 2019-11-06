//
//  SystemMessageCell.swift
//  Tok
//
//  Created by Bryce on 2019/5/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SnapKit

class SystemMessageCell: MessageCollectionViewCell {

    lazy var textLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokFootnote
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
//        let bgView = UIView()
//        bgView.backgroundColor = UIColor.tokLightGray
//        bgView.layer.cornerRadius = 12
//        bgView.layer.masksToBounds = true
//        contentView.addSubview(bgView)
        contentView.addSubview(textLabel)

//        bgView.snp.makeConstraints { (make) in
//            make.edges.equalTo(textLabel).inset(-5)
//        }
        
        textLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(30)
            make.trailing.equalTo(-30)
            make.top.bottom.equalToSuperview()
        }
    }
}
