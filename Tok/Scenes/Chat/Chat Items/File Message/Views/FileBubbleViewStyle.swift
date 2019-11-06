//
//  FileBubbleViewStyle.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class FileBubbleViewStyle {

    public let bubbleMasks: BubbleMasks
    public let bubbleImages: BubbleImages
    public let baseStyle: BaseMessageStyle
    let colors = BaseMessageStyle.createDefaultProgressColors()
    public init (baseStyle: BaseMessageStyle = BaseMessageStyle()) {
        self.bubbleImages = BaseMessageStyle.createBubbleImages()
        self.baseStyle = baseStyle
        self.bubbleMasks = BaseMessageStyle.createDefaultBubbleMasks()
    }
    
    lazy private var images: [ImageKey: UIImage] = {
        return [
            .template(isIncoming: true, showsTail: true): self.bubbleImages.incomingTail(),
            .template(isIncoming: true, showsTail: false): self.bubbleImages.incomingNoTail(),
            .template(isIncoming: false, showsTail: true): self.bubbleImages.outgoingTail(),
            .template(isIncoming: false, showsTail: false): self.bubbleImages.outgoingNoTail()
        ]
    }()
    
    private enum ImageKey: Hashable {
        case template(isIncoming: Bool, showsTail: Bool)
        case normal(isIncoming: Bool, status: MessageViewModelStatus, showsTail: Bool, isSelected: Bool)
    }
    
    func createImage(templateImage image: UIImage, isIncoming: Bool, status: MessageViewModelStatus, isSelected: Bool) -> UIImage {
        var color = self.baseStyle.baseColorIncoming
        
        switch status {
        case .success:
            break
        case .failed, .sending:
            color = color.bma_blendWithColor(UIColor.white.withAlphaComponent(0.30))
        }
        
        if isSelected {
            color = color.bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
        }
        
        return image.bma_tintWithColor(color)
    }
    
    func bubbleImage(viewModel: FileMessageViewModel, isSelected: Bool) -> UIImage {
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
    
    lazy private var maskImageIncomingTail: UIImage = self.bubbleMasks.incomingTail()
    lazy private var maskImageIncomingNoTail: UIImage = self.bubbleMasks.incomingNoTail()
    lazy private var maskImageOutgoingTail: UIImage = self.bubbleMasks.outgoingTail()
    lazy private var maskImageOutgoingNoTail: UIImage = self.bubbleMasks.outgoingNoTail()
    func maskingImage(viewModel: FileMessageViewModel) -> UIImage {
        switch (viewModel.isIncoming, viewModel.decorationAttributes.isShowingTail) {
        case (true, true):
            return self.maskImageIncomingTail
        case (true, false):
            return self.maskImageIncomingNoTail
        case (false, true):
            return self.maskImageOutgoingTail
        case (false, false):
            return self.maskImageOutgoingNoTail
        }
    }
    
    func contentInsets(viewModel: FileMessageViewModel) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    func tailWidth(viewModel: FileMessageViewModel) -> CGFloat {
        return self.bubbleMasks.tailWidth
    }
    
    func progressIndicatorColor(viewModel: FileMessageViewModel) -> UIColor {
        return viewModel.isIncoming ? self.colors.progressIndicatorColorIncoming : self.colors.progressIndicatorColorOutgoing
    }
    
    func overlayColor(viewModel: FileMessageViewModel) -> UIColor? {
        var showsOverlay: Bool
        switch viewModel.transferStatus {
        case .transfering, .idle:
            showsOverlay = true
        case .failed:
            showsOverlay = viewModel.renewable
        default:
            showsOverlay = false
        }
        return showsOverlay ? self.colors.overlayColor : nil
    }
}
