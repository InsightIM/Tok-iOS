//
//  PhotoMessageStyle.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

class PhotoMessageStyle {
    
    public struct Colors {
        public let placeholderIconTintIncoming: UIColor
        public let placeholderIconTintOutgoing: UIColor
        public let progressIndicatorColorIncoming: UIColor
        public let progressIndicatorColorOutgoing: UIColor
        public let overlayColor: UIColor
        public init(
            placeholderIconTintIncoming: UIColor,
            placeholderIconTintOutgoing: UIColor,
            progressIndicatorColorIncoming: UIColor,
            progressIndicatorColorOutgoing: UIColor,
            overlayColor: UIColor) {
            self.placeholderIconTintIncoming = placeholderIconTintIncoming
            self.placeholderIconTintOutgoing = placeholderIconTintOutgoing
            self.progressIndicatorColorIncoming = progressIndicatorColorIncoming
            self.progressIndicatorColorOutgoing = progressIndicatorColorOutgoing
            self.overlayColor = overlayColor
        }
    }
    
    let bubbleMasks: BubbleMasks = BaseMessageStyle.createDefaultBubbleMasks()
    let colors: Colors = PhotoMessageStyle.createDefaultColors()
    let baseStyle: BaseMessageCollectionViewCellDefaultStyle
    public init(
        baseStyle: BaseMessageCollectionViewCellDefaultStyle = BaseMessageCollectionViewCellDefaultStyle()) {
        self.baseStyle = baseStyle
    }
    
    lazy private var maskImageIncomingTail: UIImage = self.bubbleMasks.incomingTail()
    lazy private var maskImageIncomingNoTail: UIImage = self.bubbleMasks.incomingNoTail()
    lazy private var maskImageOutgoingTail: UIImage = self.bubbleMasks.outgoingTail()
    lazy private var maskImageOutgoingNoTail: UIImage = self.bubbleMasks.outgoingNoTail()
    
    lazy private var placeholderBackgroundIncoming: UIImage = {
        return UIImage.bma_imageWithColor(UIColor("#E7E9F0"), size: CGSize(width: 1, height: 1))
    }()
    
    lazy private var placeholderBackgroundOutgoing: UIImage = {
        return UIImage.bma_imageWithColor(UIColor("#E7E9F0"), size: CGSize(width: 1, height: 1))
    }()
    
    lazy private var placeholderIcon: UIImage = {
        return UIImage(named: "PhotoPlaceholder")!
    }()
    
    open func maskingImage(viewModel: PhotoMessageViewModel) -> UIImage {
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
    
    open func borderImage(viewModel: PhotoMessageViewModel) -> UIImage? {
        return self.baseStyle.borderImage(viewModel: viewModel)
    }
    
    open func placeholderBackgroundImage(viewModel: PhotoMessageViewModel) -> UIImage {
        return viewModel.isIncoming ? self.placeholderBackgroundIncoming : self.placeholderBackgroundOutgoing
    }
    
    open func placeholderIconImage(viewModel: PhotoMessageViewModel) -> UIImage {
        return self.placeholderIcon
    }
    
    open func placeholderIconTintColor(viewModel: PhotoMessageViewModel) -> UIColor {
        return viewModel.isIncoming ? self.colors.placeholderIconTintIncoming : self.colors.placeholderIconTintOutgoing
    }
    
    open func tailWidth(viewModel: PhotoMessageViewModel) -> CGFloat {
        return self.bubbleMasks.tailWidth
    }
    
    open func bubbleSize(viewModel: PhotoMessageViewModel) -> CGSize {
        return BaseMessageStyle.meidaBubbleSize(imageSize: viewModel.imageSize)
    }
    
    open func progressIndicatorColor(viewModel: PhotoMessageViewModel) -> UIColor {
        return viewModel.isIncoming ? self.colors.progressIndicatorColorIncoming : self.colors.progressIndicatorColorOutgoing
    }
}

extension PhotoMessageStyle {
    static func createDefaultColors() -> Colors {
        return Colors(
            placeholderIconTintIncoming: UIColor.bma_color(rgb: 0xced6dc),
            placeholderIconTintOutgoing: UIColor.bma_color(rgb: 0x508dfc),
            progressIndicatorColorIncoming: UIColor.bma_color(rgb: 0x98a3ab),
            progressIndicatorColorOutgoing: UIColor.white,
            overlayColor: UIColor.black.withAlphaComponent(0.70)
        )
    }
}
