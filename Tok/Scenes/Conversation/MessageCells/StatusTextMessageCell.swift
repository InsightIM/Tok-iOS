//
//  StatusTextMessageCell.swift
//  Tok
//
//  Created by Bryce on 2018/12/11.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

final class StatusTextMessageCell: TextMessageCell {
    
    var status: MessageStatus = .waiting {
        didSet {
            switch status {
            case .failed, .waiting, .unread:
                statusImageView.image = nil
            case .sending, .sent:
                statusImageView.image = UIImage(named: status.imageName)
            }
        }
    }
    
    private var statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(statusImageView)
        statusImageView.snp.makeConstraints { (make) in
            make.right.equalTo(-12)
            make.bottom.equalTo(-6)
            make.size.equalTo(CGSize(width: 10, height: 10))
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        status = .waiting
    }
    
//    override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
//        super.configure(with: message, at: indexPath, and: messagesCollectionView)
//    }
    
    func bind(with message: MessageModel) {
        guard case .text = message.kind else { return }
        status = message.status
    }
}
