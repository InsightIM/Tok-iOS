//
//  TextMessageStyle.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

class TextMessageStyle {
    public struct BubbleImages {
        let incomingTail: () -> UIImage
        let incomingNoTail: () -> UIImage
        let outgoingTail: () -> UIImage
        let outgoingNoTail: () -> UIImage
        public init(
            incomingTail: @autoclosure @escaping () -> UIImage,
            incomingNoTail: @autoclosure @escaping () -> UIImage,
            outgoingTail: @autoclosure @escaping () -> UIImage,
            outgoingNoTail: @autoclosure @escaping () -> UIImage) {
            self.incomingTail = incomingTail
            self.incomingNoTail = incomingNoTail
            self.outgoingTail = outgoingTail
            self.outgoingNoTail = outgoingNoTail
        }
    }
    
    public struct TextStyle {
        public let font: () -> UIFont
        public let incomingColor: () -> UIColor
        public let outgoingColor: () -> UIColor
        public let linkTextColor: () -> UIColor
        public let incomingInsets: UIEdgeInsets
        public let outgoingInsets: UIEdgeInsets
        public init(
            font: @autoclosure @escaping () -> UIFont,
            incomingColor: @autoclosure @escaping () -> UIColor,
            outgoingColor: @autoclosure @escaping () -> UIColor,
            linkTextColor: @autoclosure @escaping () -> UIColor,
            incomingInsets: UIEdgeInsets,
            outgoingInsets: UIEdgeInsets) {
            self.font = font
            self.incomingColor = incomingColor
            self.outgoingColor = outgoingColor
            self.linkTextColor = linkTextColor
            self.incomingInsets = incomingInsets
            self.outgoingInsets = outgoingInsets
        }
    }
    
    public let bubbleImages: BubbleImages
    public let bubbleStatusImages: BubbleStatusImages
    public let textStyle: TextStyle
    public let baseStyle: BaseMessageCollectionViewCellDefaultStyle
    public init (
        bubbleImages: BubbleImages = TextMessageStyle.createBubbleImages(),
        bubbleStatusImages: BubbleStatusImages = BaseMessageStyle.createDefaultBubbleStatusImages(),
        textStyle: TextStyle = TextMessageStyle.createTextStyle(),
        baseStyle: BaseMessageCollectionViewCellDefaultStyle = BaseMessageCollectionViewCellDefaultStyle()) {
        self.bubbleImages = bubbleImages
        self.bubbleStatusImages = bubbleStatusImages
        self.textStyle = textStyle
        self.baseStyle = baseStyle
    }
    
    lazy private var images: [ImageKey: UIImage] = {
        return [
            .template(isIncoming: true, showsTail: true): self.bubbleImages.incomingTail(),
            .template(isIncoming: true, showsTail: false): self.bubbleImages.incomingNoTail(),
            .template(isIncoming: false, showsTail: true): self.bubbleImages.outgoingTail(),
            .template(isIncoming: false, showsTail: false): self.bubbleImages.outgoingNoTail()
        ]
    }()
    
    lazy var font: UIFont = textStyle.font()
    lazy var incomingColor: UIColor = textStyle.incomingColor()
    lazy var outgoingColor: UIColor = textStyle.outgoingColor()
    lazy var linkTextColor = textStyle.linkTextColor()
    
    open func textFont(viewModel: TextMessageViewModel, isSelected: Bool) -> UIFont {
        return self.font
    }
    
    open func linkTextColor(viewModel: TextMessageViewModel, isSelected: Bool) -> UIColor {
        return linkTextColor
    }
    
    open func textColor(viewModel: TextMessageViewModel, isSelected: Bool) -> UIColor {
        return viewModel.isIncoming ? self.incomingColor : self.outgoingColor
    }
    
    open func textInsets(viewModel: TextMessageViewModel, isSelected: Bool) -> UIEdgeInsets {
        if shouldShowStatus(viewModel: viewModel) {
            return UIEdgeInsets(top: self.textStyle.outgoingInsets.top,
                                left: self.textStyle.outgoingInsets.left,
                                bottom: self.textStyle.outgoingInsets.bottom,
                                right: self.textStyle.outgoingInsets.right + 10.0 + 5.0)
        }
        return viewModel.isIncoming ? self.textStyle.incomingInsets : self.textStyle.outgoingInsets
    }
    
    open func shouldShowStatus(viewModel: TextMessageViewModel) -> Bool {
        let isIncoming = viewModel.messageViewModel.isIncoming
        let status = viewModel.messageViewModel.status
        
        guard isIncoming == false else {
            return false
        }
        
        switch status {
        case .sending, .success:
            return true
        case .failed:
            return false
        }
    }
    
    open func bubbleStatusImage(viewModel: TextMessageViewModel) -> UIImage? {
        guard viewModel.isIncoming == false else {
            return nil
        }
        
        switch viewModel.status {
        case .sending:
            return bubbleStatusImages.sending()
        case .success:
            return bubbleStatusImages.success()
        case .failed:
            return nil
        }
    }
    
    open func bubbleImageBorder(viewModel: TextMessageViewModel, isSelected: Bool) -> UIImage? {
        return self.baseStyle.borderImage(viewModel: viewModel)
    }
    
    open func bubbleImage(viewModel: TextMessageViewModel, isSelected: Bool) -> UIImage {
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
}

extension TextMessageStyle { // Default values
    static public func createBubbleImages() -> BubbleImages {
        return BubbleImages(
            incomingTail: UIImage(named: "bubble_incoming_tail")!,
            incomingNoTail: UIImage(named: "bubble_incoming")!,
            outgoingTail: UIImage(named: "bubble_outgoing_tail")!,
            outgoingNoTail: UIImage(named: "bubble_outgoing")!
        )
    }
    
    static public func createTextStyle() -> TextStyle {
        return TextStyle(
            font: UIFont.systemFont(ofSize: 17),
            incomingColor: UIColor.black,
            outgoingColor: UIColor.black,
            linkTextColor: UIColor.tokLink,
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )
    }
}
