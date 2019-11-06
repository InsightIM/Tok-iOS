//
//  DiscoverStyleView.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class DiscoverStyleView: UIView {
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .tokTitle4
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    lazy var detailTextView: UITextView = {
        let textView = UITextView()
        textView.textColor = .tokTitle4
        textView.textAlignment = .center
        textView.isEditable = false
        return textView
    }()
    
    lazy var editButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "Edit"), for: .normal)
        button.setImage(UIImage(named: "EditHL"), for: .highlighted)
        return button
    }()

    init(editStyle: Bool = false) {
        super.init(frame: .zero)
        
        backgroundColor = .white
        layer.cornerRadius = 4
        layer.masksToBounds = true
        
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(detailTextView)
        
        avatarImageView.snp.makeConstraints { (make) in
            make.top.equalTo(18)
            make.centerX.equalToSuperview()
            make.size.equalTo(40)
        }
        nameLabel.snp.makeConstraints { (make) in
            make.top.equalTo(avatarImageView.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
            make.leading.equalTo(18)
            make.trailing.equalTo(-18)
        }
        
        if editStyle {
            addSubview(editButton)
            
            editButton.snp.makeConstraints { (make) in
                make.top.equalTo(nameLabel.snp.bottom).offset(12)
                make.trailing.equalTo(-18)
                make.size.equalTo(24)
            }
            detailTextView.snp.makeConstraints { (make) in
                make.top.equalTo(editButton.snp.bottom).offset(12)
                make.leading.equalTo(18)
                make.trailing.equalTo(-18)
                make.bottom.equalTo(-18)
            }
        } else {
            detailTextView.snp.makeConstraints { (make) in
                make.top.equalTo(nameLabel.snp.bottom).offset(12)
                make.leading.equalTo(18)
                make.trailing.equalTo(-18)
                make.bottom.equalTo(-18)
            }
        }
    }
    
    var text: String? {
        didSet {
            guard let text = text else { return }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 15
            detailTextView.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: paragraphStyle,
                                                                                          .font: UIFont.systemFont(ofSize: 16)])
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
