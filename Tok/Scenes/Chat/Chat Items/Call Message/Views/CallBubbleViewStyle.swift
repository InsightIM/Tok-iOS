//
//  CallBubbleViewStyle.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class CallBubbleViewStyle {
    public let bubbleMasks: BubbleMasks
    
    public let baseStyle: BaseMessageStyle
    public init (
        bubbleMasks: BubbleMasks = BaseMessageStyle.createDefaultBubbleMasks(),
        baseStyle: BaseMessageStyle = BaseMessageStyle()) {
        self.bubbleMasks = bubbleMasks
        self.baseStyle = baseStyle
    }
    
    lazy private var images: [ImageKey: UIImage] = {
        return [
            .template(isIncoming: true, showsTail: true): self.bubbleMasks.incomingTail(),
            .template(isIncoming: true, showsTail: false): self.bubbleMasks.incomingNoTail(),
            .template(isIncoming: false, showsTail: true): self.bubbleMasks.outgoingTail(),
            .template(isIncoming: false, showsTail: false): self.bubbleMasks.outgoingNoTail()
        ]
    }()
    
    open func bubbleImage(viewModel: CallMessageViewModel, isSelected: Bool) -> UIImage {
        let key = ImageKey.normal(isIncoming: viewModel.isIncoming, status: viewModel.status, showsTail: viewModel.decorationAttributes.isShowingTail, isSelected: isSelected)
        
        if let image = self.images[key] {
            return image
        } else {
            let templateKey = ImageKey.template(isIncoming: viewModel.isIncoming, showsTail: viewModel.decorationAttributes.isShowingTail)
            if let image = self.images[templateKey] {
                let image = self.createImage(templateImage: image, isIncoming: viewModel.isIncoming, status: viewModel.status, isSelected: isSelected)
                self.images[key] = image
                return image
            }
        }
        
        assert(false, "coulnd't find image for this status. ImageKey: \(key)")
        return UIImage()
    }
    
    open func createImage(templateImage image: UIImage, isIncoming: Bool, status: MessageViewModelStatus, isSelected: Bool) -> UIImage {
        var color = isIncoming ? self.baseStyle.baseColorIncoming : self.baseStyle.baseColorOutgoing
        
        if isSelected {
            color = color.bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
        }
        
        return image.bma_tintWithColor(color)
    }
    
    private enum ImageKey: Hashable {
        case template(isIncoming: Bool, showsTail: Bool)
        case normal(isIncoming: Bool, status: MessageViewModelStatus, showsTail: Bool, isSelected: Bool)
    }
    
    func contentInsets(viewModel: CallMessageViewModel) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    func tailWidth(viewModel: CallMessageViewModel) -> CGFloat {
        return self.bubbleMasks.tailWidth
    }
}
