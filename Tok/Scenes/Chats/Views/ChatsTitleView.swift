//
//  ChatsTitleView.swift
//  Tok
//
//  Created by Bryce on 2019/7/5.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class ChatsTitleView: UIView {
    lazy var connetingView = ActivityIndicatorView()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokBlack
        return label
    }()
    
    var isConnected: Bool = false {
        didSet {
            if isConnected {
                titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
                titleLabel.text = NSLocalizedString("Chats", comment: "")
                connetingView.stopAnimating()
            } else {
                titleLabel.font = UIFont.systemFont(ofSize: 16)
                titleLabel.text = NSLocalizedString("Connecting", comment: "")
                connetingView.startAnimating()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        connetingView.tintColor = UIColor.tokFootnote
        let stackView = UIStackView(arrangedSubviews: [connetingView, titleLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10
        addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
