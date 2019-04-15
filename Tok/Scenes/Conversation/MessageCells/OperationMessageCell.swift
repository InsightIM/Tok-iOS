//
//  OperationMessageCell.swift
//  Tok
//
//  Created by Bryce on 2019/4/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class OperationMessageCell: MessageContentCell {
    
    var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor("#555567")
        return imageView
    }()
    
    lazy var marker: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    lazy var progressView = ProgressButton()
    
    lazy var operationButton: UIButton = {
        let button = UIButton()
        return button
    }()
    
    var status: FileTransferProgress = .waiting {
        didSet {
            updateViews()
        }
    }
    
    var isOutgoing: Bool = false {
        didSet {
            let image = isOutgoing ? UIImage(named: "CancelUpload") : UIImage(named: "Download")
            operationButton.setImage(image, for: UIControl.State())
        }
    }
    
    // MARK: - Methods
    
    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        imageView.fillSuperview()
        
        marker.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        progressView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }
        
        operationButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }
    }
    
    open override func setupSubviews() {
        super.setupSubviews()
        setupCustomViews()
        setupConstraints()
    }
    
    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let message = message as? MessageModel else {
            return
        }
        
        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            fatalError(MessageKitError.nilMessagesDisplayDelegate)
        }
        
        switch message.kind {
        case .photo(let mediaItem), .video(let mediaItem):
            let model = mediaItem as! MediaModel
            imageView.image = model.image ?? mediaItem.placeholderImage
            isOutgoing = message.isOutgoing
            status = model.status.value
        case .audio(let item):
            let model = item as! AudioMessageModel
            isOutgoing = message.isOutgoing
            status = model.status.value
        default:
            break
        }
        
        displayDelegate.configureMediaMessageImageView(imageView, for: message, at: indexPath, in: messagesCollectionView)
    }
    
    open func setupCustomViews() {
        messageContainerView.addSubview(imageView)
        messageContainerView.addSubview(marker)
        messageContainerView.addSubview(operationButton)
        messageContainerView.addSubview(progressView)
    }
    
    // MARK: - Private Methods
    
    private func updateViews() {
        switch status {
        case .failed:
            marker.isHidden = true
            progressView.isHidden = true
            operationButton.isHidden = true
        case .loading:
            marker.isHidden = false
            progressView.isHidden = false
            operationButton.isHidden = true
        case .success:
            marker.isHidden = true
            progressView.isHidden = true
            operationButton.isHidden = true
        case .waiting:
            marker.isHidden = false
            progressView.isHidden = !isOutgoing
            operationButton.isHidden = isOutgoing
        }
    }
}
