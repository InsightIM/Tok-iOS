//
//  OperationMessageCell.swift
//  Tok
//
//  Created by Bryce on 2019/4/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import YYImage

class OperationMessageCell: MessageContentCell {
    
    lazy var imageView: YYAnimatedImageView = {
        let imageView = YYAnimatedImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        return imageView
    }()
    
    lazy var placeholder: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.backgroundColor = UIColor("#E7E9F0")
        return imageView
    }()
    
    lazy var operationButton: NetworkOperationButton = NetworkOperationButton(type: .custom)
    
    lazy var sizeLabel: UILabel = {
        let label = InsetTextLabel()
        label.layer.backgroundColor = UIColor.black.withAlphaComponent(0.4).cgColor
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 1
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        return label
    }()
    
    var status: FileTransferProgress = .waiting {
        didSet {
            updateViews()
        }
    }
    
    var isOutgoing: Bool = false
    
    var canPlay: Bool = false
    
    // MARK: - Methods
    
    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        placeholder.fillSuperview()
        imageView.fillSuperview()
        
        operationButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }
        
        sizeLabel.snp.makeConstraints { (make) in
            make.bottom.right.equalTo(-6)
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
        case .photo(let mediaItem):
            let model = mediaItem as! MediaModel
            imageView.image = model.image
            placeholder.image = model.placeholderImage
            isOutgoing = message.isOutgoing
            status = model.status.value
            sizeLabel.text = mediaItem.fileSize
            canPlay = false
        case .video(let mediaItem):
            let model = mediaItem as! MediaModel
            imageView.image = model.image
            placeholder.image = model.placeholderImage
            isOutgoing = message.isOutgoing
            status = model.status.value
            sizeLabel.text = mediaItem.fileSize
            canPlay = true
        case .audio(let item):
            let model = item as! AudioMessageModel
            isOutgoing = message.isOutgoing
            status = model.status.value
            sizeLabel.text = nil
            canPlay = false
        default:
            break
        }
        
        displayDelegate.configureMediaMessageImageView(imageView, for: message, at: indexPath, in: messagesCollectionView)
    }
    
    open func setupCustomViews() {
        messageContainerView.addSubview(placeholder)
        messageContainerView.addSubview(imageView)
        messageContainerView.addSubview(operationButton)
        messageContainerView.addSubview(sizeLabel)
    }
    
    // MARK: - Private Methods
    
    private func updateViews() {
        switch status {
        case .failed:
            operationButton.isHidden = false
            sizeLabel.isHidden = true
            operationButton.style = .finished(showPlayIcon: isOutgoing ? canPlay : false)
        case .loading:
            operationButton.isHidden = false
            sizeLabel.isHidden = false
        case .success:
            operationButton.isHidden = false
            sizeLabel.isHidden = true
            operationButton.style = .finished(showPlayIcon: canPlay)
        case .waiting:
            operationButton.isHidden = false
            sizeLabel.isHidden = false
            operationButton.style = isOutgoing ? .upload : .download
        case .expired:
            operationButton.isHidden = true
            sizeLabel.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        operationButton.style = .finished(showPlayIcon: false)
    }
}
