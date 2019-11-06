//
//  TipMessageCell.swift
//  Tok
//
//  Created by Bryce on 2019/1/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class TipMessageCell: MessageCollectionViewCell {
    
    lazy var textLabel: InsetTextLabel = {
        let label = InsetTextLabel()
        label.layer.backgroundColor = UIColor("#FFF7AD").cgColor
        label.textColor = UIColor.tokBlack
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.contentInset = UIEdgeInsets(top: 1, left: 10, bottom: 1, right: 10)
        return label
    }()
    
    var didTap: (() -> Void)?
    
    private let tap = UITapGestureRecognizer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        contentView.addGestureRecognizer(tap)
        tap.addTarget(self, action: #selector(self.didClickTap))
    }
    
    @objc private func didClickTap() {
        didTap?()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
        contentView.addSubview(textLabel)
        
        textLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(20)
            make.trailing.lessThanOrEqualTo(-20)
            make.bottom.equalTo(-10)
            make.top.equalTo(10)
        }
    }
}
