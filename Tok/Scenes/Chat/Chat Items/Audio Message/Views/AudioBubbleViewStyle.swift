//
//  AudioBubbleViewStyle.swift
//  Tok
//
//  Created by Bryce on 2019/6/6.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

extension AudioBubbleViewStyle {
    static public func createAudioImages() -> AudioImages {
        return AudioImages(incomingAnimationImages: [UIImage(named: "AudioReceiverPlay_01")!,
                                                     UIImage(named: "AudioReceiverPlay_02")!,
                                                     UIImage(named: "AudioReceiverPlay_03")!],
                           incomingImage: UIImage(named: "AudioReceiverPlay_03")!,
                           outgoingAnimationImages: [UIImage(named: "AudioSenderPlay_01")!,
                                                     UIImage(named: "AudioSenderPlay_02")!,
                                                     UIImage(named: "AudioSenderPlay_03")!],
                           outgoingImage: UIImage(named: "AudioSenderPlay_03")!)
    }
}

class AudioBubbleViewStyle {
    public struct AudioImages {
        let incomingAnimationImages: () -> [UIImage]
        let incomingImage: () -> UIImage
        let outgoingAnimationImages: () -> [UIImage]
        let outgoingImage: () -> UIImage
        
        public init(
            incomingAnimationImages: @autoclosure @escaping () -> [UIImage],
            incomingImage: @autoclosure @escaping () -> UIImage,
            outgoingAnimationImages: @autoclosure @escaping () -> [UIImage],
            outgoingImage: @autoclosure @escaping () -> UIImage) {
            self.incomingAnimationImages = incomingAnimationImages
            self.incomingImage = incomingImage
            self.outgoingAnimationImages = outgoingAnimationImages
            self.outgoingImage = outgoingImage
        }
    }
    
    public let bubbleMasks: BubbleMasks
    public let bubbleImages: BubbleImages
    public let bubbleStatusImages: BubbleStatusImages
    public let audioImages: AudioImages
    public let baseStyle: BaseMessageStyle
    let colors = BaseMessageStyle.createDefaultProgressColors()
    public init (baseStyle: BaseMessageStyle = BaseMessageStyle()) {
        self.bubbleImages = BaseMessageStyle.createBubbleImages()
        self.bubbleStatusImages = BaseMessageStyle.createDefaultBubbleStatusImages()
        self.baseStyle = baseStyle
        self.audioImages = AudioBubbleViewStyle.createAudioImages()
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
        var color = isIncoming ? self.baseStyle.baseColorIncoming : self.baseStyle.baseColorOutgoing
        
        if isSelected {
            color = color.bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
        }
        
        return image.bma_tintWithColor(color)
    }
    
    func bubbleImage(viewModel: AudioMessageViewModel, isSelected: Bool) -> UIImage {
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
    
    func audioImage(viewModel: AudioMessageViewModel) -> UIImage {
        let isIncoming = viewModel.messageViewModel.isIncoming
        if isIncoming {
            return self.audioImages.incomingImage()
        } else {
            return self.audioImages.outgoingImage()
        }
    }
    
    func animationImages(viewModel: AudioMessageViewModel) -> [UIImage] {
        let isIncoming = viewModel.messageViewModel.isIncoming
        if isIncoming {
            return self.audioImages.incomingAnimationImages()
        } else {
            return self.audioImages.outgoingAnimationImages()
        }
    }
    
    lazy private var maskImageIncomingTail: UIImage = self.bubbleMasks.incomingTail()
    lazy private var maskImageIncomingNoTail: UIImage = self.bubbleMasks.incomingNoTail()
    lazy private var maskImageOutgoingTail: UIImage = self.bubbleMasks.outgoingTail()
    lazy private var maskImageOutgoingNoTail: UIImage = self.bubbleMasks.outgoingNoTail()
    func maskingImage(viewModel: AudioMessageViewModel) -> UIImage {
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
    
    func textFont(viewModel: AudioMessageViewModel) -> UIFont {
        return UIFont.systemFont(ofSize: 14)
    }
    
    func contentInsets(viewModel: AudioMessageViewModel) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    func shouldShowStatus(viewModel: AudioMessageViewModel) -> Bool {
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
    
    func bubbleStatusImage(viewModel: AudioMessageViewModel) -> UIImage? {
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
    
    func unreadImage(viewModel: AudioMessageViewModel) -> UIImage? {
        if viewModel.status == .success, viewModel.unread.value, viewModel.isIncoming {
            return UIImage(named: "UnreadDot")
        }
        return nil
    }
    
    func tailWidth(viewModel: AudioMessageViewModel) -> CGFloat {
        return self.bubbleMasks.tailWidth
    }
    
    func progressIndicatorColor(viewModel: AudioMessageViewModel) -> UIColor {
        return viewModel.isIncoming ? self.colors.progressIndicatorColorIncoming : self.colors.progressIndicatorColorOutgoing
    }
    
    func overlayColor(viewModel: AudioMessageViewModel) -> UIColor? {
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
