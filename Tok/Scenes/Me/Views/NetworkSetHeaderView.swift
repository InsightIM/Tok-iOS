//
//  NetworkSetHeaderView.swift
//  Tok
//
//  Created by gaven on 2019/10/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import WebKit

class NetworkSetHeaderView: UIView {
    
    lazy var logoImgView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "NetSetLogo")!
        return imageView
    }()
    
    var helpBlock: (() -> Void)?
    
    lazy var descLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        let a = NSLocalizedString("To make your network more stable by setting up network protocol, proxy and bootstrap nodes correctly, ", comment: "")
        let b = NSLocalizedString("click for more information", comment: "")
        
        var mutaAttr = NSMutableAttributedString(string: a,
                                                 attributes: [
                                                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                                                    NSAttributedString.Key.foregroundColor: UIColor.tokTitle4]
        )
        
        let bAttr = NSAttributedString(string: b,
                                       attributes: [
                                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                                        NSAttributedString.Key.foregroundColor: UIColor.tokLink]
        )
        mutaAttr.append(bAttr)

        let textAttachment = NSTextAttachment()
        textAttachment.bounds = CGRect(x: -3, y: -8, width: 24, height: 24)
        textAttachment.image = UIImage(named: "NetSetEnter")!
        let imgAttr = NSAttributedString(attachment: textAttachment)
        mutaAttr.append(imgAttr)
        label.attributedText = mutaAttr
        label.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(NetworkSetHeaderView.helpAction))
        label.addGestureRecognizer(tapGesture)
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        
        addSubview(logoImgView)
        addSubview(descLabel)
        
        logoImgView.snp.makeConstraints {
            $0.width.equalTo(106)
            $0.height.equalTo(106)
            $0.centerX.equalToSuperview()
            $0.top.equalTo(26)
        }
        
        descLabel.snp.makeConstraints {
            $0.left.equalTo(16)
            $0.right.equalTo(-16)
            $0.top.equalTo(logoImgView.snp_bottom).offset(24)
        }
    }
    
    @objc
    func helpAction() {
        if let helpBlock = helpBlock {
            helpBlock()
        }
    }
}
