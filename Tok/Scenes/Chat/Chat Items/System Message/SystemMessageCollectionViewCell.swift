//
//  SystemMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/6/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class SystemMessageCollectionViewCell: UICollectionViewCell {
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "Lock")
        return imageView
    }()
    
    lazy var linkTipButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.setTitleColor(.tokBlack, for: .normal)
        button.titleLabel?.numberOfLines = 0
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    private func commonInit() {
        let bgView = UIView()
        bgView.backgroundColor = UIColor("#FFF7AD")
        bgView.layer.cornerRadius = 8
        bgView.layer.masksToBounds = true
        contentView.addSubview(bgView)
        bgView.snp.makeConstraints { (make) in
            make.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(20)
            make.trailing.lessThanOrEqualTo(-20)
            make.center.equalToSuperview()
        }
        
        bgView.addSubview(imageView)
        bgView.addSubview(linkTipButton)
        
        imageView.snp.makeConstraints { (make) in
            make.leading.equalTo(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }

        linkTipButton.snp.makeConstraints { (make) in
            make.leading.equalTo(imageView.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(-10)
            make.top.bottom.equalToSuperview()
        }
        
        linkTipButton.addTarget(self, action: #selector(self.didTap), for: .touchUpInside)
    }
    
    var didTapBubbleView: (() -> Void)?
    @objc private func didTap() {
        didTapBubbleView?()
    }
    
    var text: String = "" {
        didSet {
            if oldValue != text {
                setTextOnLabel(text)
            }
        }
    }
    
    var hiddenLock: Bool = false {
        didSet {
            linkTipButton.isEnabled = !hiddenLock
            guard oldValue != hiddenLock else {
                return
            }
            
            imageView.snp.updateConstraints { (make) in
                make.leading.equalTo(hiddenLock ? 0 : 10)
                make.centerY.equalToSuperview()
                make.size.equalTo(hiddenLock ? 0 : 14)
            }
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    private func setTextOnLabel(_ text: String) {
        linkTipButton.setTitle(text, for: .normal)
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

