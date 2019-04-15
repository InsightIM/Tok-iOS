//
//  TipMessageCell.swift
//  Tok
//
//  Created by Bryce on 2019/1/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class TipMessageCell: MessageCollectionViewCell {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "Lock")
        return imageView
    }()
    
    lazy var linkTipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.tokBlack, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.titleLabel?.lineBreakMode = .byWordWrapping
        return button
    }()
    
    lazy var textLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokBlack
        label.font = UIFont.systemFont(ofSize: 12)
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
        let bgView = UIView()
        bgView.backgroundColor = UIColor("#FFF7AD")
        contentView.addSubview(bgView)
        bgView.snp.makeConstraints { (make) in
            make.left.equalTo(-10)
            make.right.equalTo(10)
            make.top.bottom.equalToSuperview()
        }
        
        contentView.addSubview(imageView)
        contentView.addSubview(textLabel)
        contentView.addSubview(linkTipButton)
        
        imageView.snp.makeConstraints { (make) in
            make.left.equalTo(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }
        
        textLabel.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.snp.right).offset(8)
            make.right.lessThanOrEqualTo(-10)
            make.top.bottom.equalToSuperview()
        }
        
        linkTipButton.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
}
