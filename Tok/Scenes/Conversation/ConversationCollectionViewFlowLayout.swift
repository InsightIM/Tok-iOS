//
//  ConversationCollectionViewFlowLayout.swift
//  Tok
//
//  Created by Bryce on 2018/10/3.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

private let avatarPosition = AvatarPosition(vertical: .messageLabelTop)
private let avatarImageSize = CGSize(width: 36, height: 36)
private let minPhotoValue: CGFloat = 80
private let maxPhotoValue: CGFloat = 200

private let incomingMediaMessagePadding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 30)
private let outgoingMediaMessagePadding = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 10)

class ConversationCollectionViewFlowLayout: MessagesCollectionViewFlowLayout {
    lazy open var customePhotoMessageSizeCalculator = PhotoMessageSizeCalculator(layout: self)
    lazy open var customMessageSizeCalculator = CustomMessageSizeCalculator(layout: self)
    lazy var customTextMessageSizeCalculator: TextMessageSizeCalculator = {
        let textMessageSizeCalculator = TextMessageSizeCalculator(layout: self)
        textMessageSizeCalculator.outgoingMessageLabelInsets = UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 18 + 10)
        return textMessageSizeCalculator
    }()
    
    override init() {
        super.init()
        setupAvatarPosition()
        setupAccessoryView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupAvatarPosition()
        setupAccessoryView()
    }
    
    private func setupAvatarPosition() {
        setMessageIncomingAvatarSize(avatarImageSize)
        setMessageOutgoingAvatarSize(avatarImageSize)
        
        setMessageIncomingAvatarPosition(avatarPosition)
        setMessageOutgoingAvatarPosition(avatarPosition)
        
        customTextMessageSizeCalculator.incomingAvatarPosition = avatarPosition
        customTextMessageSizeCalculator.outgoingAvatarPosition = avatarPosition
        
        customePhotoMessageSizeCalculator.incomingAvatarPosition = avatarPosition
        customePhotoMessageSizeCalculator.outgoingAvatarPosition = avatarPosition
        
        customMessageSizeCalculator.incomingAvatarPosition = avatarPosition
        customMessageSizeCalculator.outgoingAvatarPosition = avatarPosition
        
        customePhotoMessageSizeCalculator.incomingMessagePadding = incomingMediaMessagePadding
        customePhotoMessageSizeCalculator.outgoingMessagePadding = outgoingMediaMessagePadding
    }
    
    private func setupAccessoryView() {
        setMessageIncomingAccessoryViewSize(CGSize(width: 30, height: 30))
        setMessageIncomingAccessoryViewPadding(HorizontalEdgeInsets(left: 3, right: 0))
        setMessageOutgoingAccessoryViewSize(CGSize(width: 30, height: 30))
        setMessageOutgoingAccessoryViewPadding(HorizontalEdgeInsets(left: 0, right: 3))
    }
    
    override func messageSizeCalculators() -> [MessageSizeCalculator] {
        var messageSizeCalculators = super.messageSizeCalculators()
        messageSizeCalculators.append(contentsOf: [customePhotoMessageSizeCalculator,
                                                   customTextMessageSizeCalculator,
                                                   customMessageSizeCalculator])
        return messageSizeCalculators
    }
    
    override open func cellSizeCalculatorForItem(at indexPath: IndexPath) -> CellSizeCalculator {
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        guard let messageModel = message as? MessageModel else {
            return super.cellSizeCalculatorForItem(at: indexPath)
        }
        
        switch message.kind {
        case .text:
            switch messageModel.status {
            case .sending, .sent: return customTextMessageSizeCalculator
            case .failed, .waiting, .unread: return textMessageSizeCalculator
            }
        case .photo, .video:
            return customePhotoMessageSizeCalculator
        case .custom:
            return customMessageSizeCalculator
        default:
            return super.cellSizeCalculatorForItem(at: indexPath)
        }
    }
}

open class PhotoMessageSizeCalculator: MediaMessageSizeCalculator {
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        guard let message = message as? MessageModel, message.message.isInvalidated == false else {
            return .zero
        }
        
        if message.isOutgoing == false, message.status == .failed {
            return CGSize(width: 150, height: 140)
        }
        
        let size = super.messageContainerSize(for: message)
        let radio = size.height / size.width
        if radio > 1 {
            let height = max(min(size.height, maxPhotoValue), minPhotoValue)
            let width = height / radio
            return CGSize(width: max(width, minPhotoValue), height: height)
        } else if radio < 1 {
            let width = max(min(size.width, maxPhotoValue), minPhotoValue)
            let height = width * radio
            return CGSize(width: width, height: max(height, minPhotoValue))
        } else {
            let width = max(min(size.width, maxPhotoValue), minPhotoValue)
            return CGSize(width: width, height: width)
        }
    }
}

open class CustomMessageSizeCalculator: MessageSizeCalculator {
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        guard let message = message as? MessageModel else { return CGSize(width: 220, height: 70) }
        switch message.kind {
        case .custom(let item):
            if item is CallMessageItem {
                return CGSize(width: 180, height: 44)
            }
            
            fallthrough
        default:
            return CGSize(width: 220, height: 70)
        }
    }
}
