//
//  VideoBubbleViewStyle.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class VideoBubbleViewStyle {
    public struct BubbleMasks {
        public let incomingTail: () -> UIImage
        public let incomingNoTail: () -> UIImage
        public let outgoingTail: () -> UIImage
        public let outgoingNoTail: () -> UIImage
        public let tailWidth: CGFloat
        public init(
            incomingTail: @autoclosure @escaping () -> UIImage,
            incomingNoTail: @autoclosure @escaping () -> UIImage,
            outgoingTail: @autoclosure @escaping () -> UIImage,
            outgoingNoTail: @autoclosure @escaping () -> UIImage,
            tailWidth: CGFloat) {
            self.incomingTail = incomingTail
            self.incomingNoTail = incomingNoTail
            self.outgoingTail = outgoingTail
            self.outgoingNoTail = outgoingNoTail
            self.tailWidth = tailWidth
        }
    }
    
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
    
    let bubbleMasks: BubbleMasks
    let colors: Colors
    let baseStyle: BaseMessageCollectionViewCellDefaultStyle
    public init(
        bubbleMasks: BubbleMasks = VideoBubbleViewStyle.createDefaultBubbleMasks(),
        colors: Colors = VideoBubbleViewStyle.createDefaultColors(),
        baseStyle: BaseMessageCollectionViewCellDefaultStyle = BaseMessageCollectionViewCellDefaultStyle()) {
        self.bubbleMasks = bubbleMasks
        self.colors = colors
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
        return UIImage(named: "VideoPlaceholder")!
    }()
    
    open func maskingImage(viewModel: VideoMessageViewModel) -> UIImage {
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
    
    open func borderImage(viewModel: VideoMessageViewModel) -> UIImage? {
        return self.baseStyle.borderImage(viewModel: viewModel)
    }
    
    open func placeholderBackgroundImage(viewModel: VideoMessageViewModel) -> UIImage {
        return viewModel.isIncoming ? self.placeholderBackgroundIncoming : self.placeholderBackgroundOutgoing
    }
    
    open func placeholderIconImage(viewModel: VideoMessageViewModel) -> UIImage {
        return self.placeholderIcon
    }
    
    open func placeholderIconTintColor(viewModel: VideoMessageViewModel) -> UIColor {
        return viewModel.isIncoming ? self.colors.placeholderIconTintIncoming : self.colors.placeholderIconTintOutgoing
    }
    
    open func tailWidth(viewModel: VideoMessageViewModel) -> CGFloat {
        return self.bubbleMasks.tailWidth
    }
    
    open func bubbleSize(viewModel: VideoMessageViewModel) -> CGSize {
        return BaseMessageStyle.meidaBubbleSize(imageSize: viewModel.imageSize)
    }
    
    open func progressIndicatorColor(viewModel: VideoMessageViewModel) -> UIColor {
        return viewModel.isIncoming ? self.colors.progressIndicatorColorIncoming : self.colors.progressIndicatorColorOutgoing
    }
    
    open func overlayColor(viewModel: VideoMessageViewModel) -> UIColor? {
        let showsOverlay = viewModel.image.value != nil && (viewModel.transferStatus == .transfering || viewModel.status != MessageViewModelStatus.success)
        return showsOverlay ? self.colors.overlayColor : nil
    }
    
}

extension VideoBubbleViewStyle { // Default values
    
    static func createDefaultBubbleMasks() -> BubbleMasks {
        return BubbleMasks(
            incomingTail: UIImage(named: "bubble-incoming-tail")!,
            incomingNoTail: UIImage(named: "bubble-incoming")!,
            outgoingTail: UIImage(named: "bubble-outgoing-tail")!,
            outgoingNoTail: UIImage(named: "bubble-outgoing")!,
            tailWidth: 6
        )
    }
    
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
