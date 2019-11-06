//
//  CallMessageCell.swift
//  Tok
//
//  Created by Bryce on 2018/11/1.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

class CallMessageCell: MessageContentCell {
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "callMessage")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.font = UIFont.systemFont(ofSize: 15)
        return label
    }()
    
    // MARK: - Methods
    
    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        iconImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 24, height: 12))
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
        }
        
        durationLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalTo(iconImageView.snp.right).offset(10)
            make.right.equalTo(-10)
        }
    }
    
    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(iconImageView)
        messageContainerView.addSubview(durationLabel)
        
        setupConstraints()
    }
    
    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let message = message as? MessageModel else { return }

        let left = message.isOutgoing ? 12 : 18
        iconImageView.snp.updateConstraints { (make) in
            make.left.equalTo(left)
        }
        
        guard let _ = messagesCollectionView.messagesDisplayDelegate else {
            return
        }
        
        switch message.kind {
        case .custom(let item):
            guard let call = item as? CallMessageItem else {
                return
            }
            
            let duration = NSLocalizedString("Duration:", comment: "")
            if message.isOutgoing {
                durationLabel.text = call.answered ? "\(duration) \(String(timeInterval: call.duration))" : NSLocalizedString("Unanswered call", comment: "")
            } else {
                durationLabel.text = call.answered ? "\(duration) \(String(timeInterval: call.duration))" : NSLocalizedString("Missed call", comment: "")
            }
        default:
            break
        }
    }
}
