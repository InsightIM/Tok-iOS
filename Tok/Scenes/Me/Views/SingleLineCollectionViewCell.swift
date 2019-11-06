//
//  PortraitCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import Reusable
import SnapKit

class SingleLineCollectionViewCell: UICollectionViewCell {
    
    var model: (String, String)? {
        didSet {
            if let model = model {
                self.updateView(model)
            }
        }
    }
    
    lazy var indicatorView: UIImageView = {
        let indicatorView = UIImageView()
        indicatorView.image = UIImage(named: "RightArrow")
        return indicatorView
    }()
    
    lazy var detailLabel: UILabel = {
        let detailLabel = UILabel()
        detailLabel.textColor = UIColor.tokBlack.withAlphaComponent(0.4)
        detailLabel.font = UIFont.systemFont(ofSize: 16)
        return detailLabel
    }()
    
    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = UIColor.tokBlack
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        return titleLabel
    }()
    
    lazy var bottomLine: UIView = {
        let line = UIView()
        line.backgroundColor = UIColor("#efefef")
        return line
    }()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(self.indicatorView)
        self.addSubview(self.titleLabel)
        self.addSubview(self.detailLabel)
        
        self.indicatorView.snp.makeConstraints { (make) in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        self.detailLabel.snp.makeConstraints { (make) in
            make.right.equalTo(self.indicatorView.snp.left).offset(-6)
            make.centerY.equalToSuperview()
        }
        self.titleLabel.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.right.lessThanOrEqualTo(self.detailLabel.snp.left).offset(-6)
            make.centerY.equalToSuperview()
        }
        
        self.addSubview(self.bottomLine)
        bottomLine.snp.makeConstraints { (make) in
            make.height.equalTo(1)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    func updateView(_ model: (String, String)) {
        self.titleLabel.text = model.0
        self.detailLabel.text = model.1
    }
}
