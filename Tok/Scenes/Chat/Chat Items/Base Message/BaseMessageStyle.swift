//
//  BaseMessageStyle.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import Device

let minPhotoValue: CGFloat = 150
let maxPhotoValue: CGFloat = Device.size() > .screen4_7Inch ? 280 : 220

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

public struct BubbleStatusImages {
    let sending: () -> UIImage
    let success: () -> UIImage
    
    public init(
        sending: @autoclosure @escaping () -> UIImage,
        success: @autoclosure @escaping () -> UIImage) {
        self.sending = sending
        self.success = success
    }
}

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

public struct ProgressIndicatorColors {
    public let progressIndicatorColorIncoming: UIColor
    public let progressIndicatorColorOutgoing: UIColor
    public let overlayColor: UIColor
    public init(
        progressIndicatorColorIncoming: UIColor,
        progressIndicatorColorOutgoing: UIColor,
        overlayColor: UIColor) {
        self.progressIndicatorColorIncoming = progressIndicatorColorIncoming
        self.progressIndicatorColorOutgoing = progressIndicatorColorOutgoing
        self.overlayColor = overlayColor
    }
}

class BaseMessageStyle: BaseMessageCollectionViewCellDefaultStyle {
    
    init() {
        super.init(colors: BaseMessageStyle.createColors(),
                   bubbleBorderImages: nil,
                   failedIconImages: BaseMessageStyle.createFailedIconImages(),
                   avatarStyle: AvatarStyle(size: .zero, alignment: .top))
    }
    
    override func avatarSize(viewModel: MessageViewModelProtocol) -> CGSize {
        return CGSize(width: 35, height: 35)
    }
    
    override func borderImage(viewModel: MessageViewModelProtocol) -> UIImage? {
        return nil
    }
}

extension BaseMessageStyle { // Default values
    
    private static let defaultIncomingColor = UIColor.bma_color(rgb: 0xFFFFFF)
    private static let defaultOutgoingColor = UIColor.bma_color(rgb: 0xC5EDFE)
    
    static func createColors() -> Colors {
        return Colors(incoming: self.defaultIncomingColor, outgoing: self.defaultOutgoingColor)
    }
    
    static func createFailedIconImages() -> FailedIconImages {
        let normal = {
            return UIImage(named: "base-message-failed-icon")!
        }
        return FailedIconImages(
            normal: normal(),
            highlighted: normal().bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
        )
    }
    
    static func createDateTextStyle() -> DateTextStyle {
        return DateTextStyle(font: UIFont.systemFont(ofSize: 12), color: UIColor.bma_color(rgb: 0x9aa3ab))
    }
    
    static func createLayoutConstants() -> BaseMessageCollectionViewCellLayoutConstants {
        return BaseMessageCollectionViewCellLayoutConstants(horizontalMargin: 11,
                                                            horizontalInterspacing: 4,
                                                            horizontalTimestampMargin: 11,
                                                            maxContainerWidthPercentageForBubbleView: 0.68)
    }
    
    private static let selectionIndicatorIconSelected = UIImage(named: "base-message-checked-icon")!.bma_tintWithColor(BaseMessageStyle.defaultOutgoingColor)
    private static let selectionIndicatorIconDeselected = UIImage(named: "base-message-unchecked-icon")!.bma_tintWithColor(UIColor.bma_color(rgb: 0xC6C6C6))
    
    static func createSelectionIndicatorStyle() -> SelectionIndicatorStyle {
        return SelectionIndicatorStyle(
            margins: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10),
            selectedIcon: self.selectionIndicatorIconSelected,
            deselectedIcon: self.selectionIndicatorIconDeselected
        )
    }
    
    static func createBubbleImages() -> BubbleImages {
        return BubbleImages(
            incomingTail: UIImage(named: "bubble_incoming_tail")!,
            incomingNoTail: UIImage(named: "bubble_incoming")!,
            outgoingTail: UIImage(named: "bubble_outgoing_tail")!,
            outgoingNoTail: UIImage(named: "bubble_outgoing")!
        )
    }
    
    static func createDefaultProgressColors() -> ProgressIndicatorColors {
        return ProgressIndicatorColors(
            progressIndicatorColorIncoming: UIColor.bma_color(rgb: 0x98a3ab),
            progressIndicatorColorOutgoing: UIColor.white,
            overlayColor: UIColor.black.withAlphaComponent(0.50)
        )
    }
    
    static func createDefaultBubbleStatusImages() -> BubbleStatusImages {
        return BubbleStatusImages(
            sending: UIImage(named: "text-status-sending")!,
            success: UIImage(named: "text-status-success")!
        )
    }
    
    static public func createDefaultBubbleMasks() -> BubbleMasks {
        return BubbleMasks(
            incomingTail: UIImage(named: "bubble_incoming_tail")!,
            incomingNoTail: UIImage(named: "bubble_incoming_tail")!,
            outgoingTail: UIImage(named: "bubble_outgoing_tail")!,
            outgoingNoTail: UIImage(named: "bubble_outgoing_tail")!,
            tailWidth: 6
        )
    }
    
    static func meidaBubbleSize(imageSize: CGSize) -> CGSize {
        guard imageSize != .zero else {
            return CGSize(width: 200, height: 150)
        }
        let size = imageSize
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
