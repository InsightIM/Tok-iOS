//
//  TimeSeparatorCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto

class TimeSeparatorCollectionViewCell: UICollectionViewCell {
    private let label: UILabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    private func commonInit() {
        self.label.font = UIFont.systemFont(ofSize: 12)
        self.label.textAlignment = .center
        self.label.textColor = UIColor.gray
        self.contentView.addSubview(label)
    }
    
    var text: String = "" {
        didSet {
            if oldValue != text {
                self.setTextOnLabel(text)
            }
        }
    }
    
    private func setTextOnLabel(_ text: String) {
        self.label.text = text
        self.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.label.bounds.size = self.label.sizeThatFits(self.contentView.bounds.size)
        self.label.center = self.contentView.center
    }
}
