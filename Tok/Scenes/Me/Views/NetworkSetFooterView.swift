//
//  NetworkSetFooterView.swift
//  Tok
//
//  Created by gaven on 2019/10/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import WebKit

class NetworkSetFooterView: UIView {
    
    lazy var descLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = UIColor.tokFootnote
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.text = NSLocalizedString("Support for multiple nodes at the same time. Use the Node you configured for the connection first, then use the Node of the system cache after all failure.", comment: "")
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
        backgroundColor = .clear
        addSubview(descLabel)
        
        descLabel.snp.makeConstraints {
            $0.left.equalTo(16)
            $0.right.equalTo(-16)
            $0.top.equalTo(6)
        }
    }
}
