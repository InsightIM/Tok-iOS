//
//  CallBubbleView.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class CallBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
    public var viewContext: ViewContext = .normal
    public var animationDuration: CFTimeInterval = 0.33
    public var preferredMaxLayoutWidth: CGFloat = 0
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    private func commonInit() {
        addSubview(bubbleImageView)
        addSubview(iconImageView)
        addSubview(durationLabel)
    }
    
    private lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.accessibilityIdentifier = "chatto.message.call.image.bubble"
        return imageView
    }()
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "callMessage")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.font = UIFont.systemFont(ofSize: 15)
        return label
    }()
    
    var selected: Bool = false {
        didSet {
            if self.selected != oldValue {
                self.updateViews()
            }
        }
    }

    var viewModel: CallMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.bubbleAccessibilityIdentifier
            self.updateViews()
        }
    }
    
    var messageStyle: CallBubbleViewStyle! {
        didSet {
            self.updateViews()
        }
    }
    
    public private(set) var isUpdating: Bool = false
    public func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        self.isUpdating = true
        let updateAndRefreshViews = {
            updateClosure()
            self.isUpdating = false
            self.updateViews()
            if animated {
                self.layoutIfNeeded()
            }
        }
        if animated {
            UIView.animate(withDuration: self.animationDuration, animations: updateAndRefreshViews, completion: { (_) -> Void in
                completion?()
            })
        } else {
            updateAndRefreshViews()
        }
    }
    
    open func updateViews() {
        if self.viewContext == .sizing { return }
        if isUpdating { return }
        guard self.viewModel != nil, self.messageStyle != nil else { return }
        
        self.updateText()
        self.updateImages()
    }
    
    private func updateText() {
        durationLabel.text = viewModel.text
    }
    
    private func updateImages() {
        let bubbleImage = messageStyle.bubbleImage(viewModel: viewModel, isSelected: self.selected)
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
    }
    
    // MARK: Layout
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateBubbleLayout(maximumWidth: size.width).size
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        let layout = calculateBubbleLayout(maximumWidth: preferredMaxLayoutWidth)
        bubbleImageView.bma_rect = layout.bubbleFrame
        bubbleImageView.layer.mask?.frame = bubbleImageView.layer.bounds
        iconImageView.bma_rect = layout.iconFrame
        durationLabel.bma_rect = layout.durationFrame
    }
    
    private func calculateBubbleLayout(maximumWidth: CGFloat) -> CallBubbleLayoutModel {
        let layoutContext = CallBubbleLayoutModel.LayoutContext(isIncoming: viewModel.isIncoming,
                                                                contentInsets: messageStyle.contentInsets(viewModel: viewModel),
                                                                tailWidth: messageStyle.tailWidth(viewModel: viewModel),
                                                                text: viewModel.text,
                                                                font: durationLabel.font,
                                                                textInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10),
                                                                preferredMaxLayoutWidth: preferredMaxLayoutWidth)
        
        let layoutModel = CallBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        
        return layoutModel
    }
    
    open var canCalculateSizeInBackground: Bool {
        return true
    }
}

private class CallBubbleLayoutModel {
    var bubbleFrame: CGRect = .zero
    var durationFrame: CGRect = .zero
    var iconFrame: CGRect = .zero
    var size: CGSize = CGSize.zero
    
    struct LayoutContext {
        let isIncoming: Bool
        let contentInsets: UIEdgeInsets
        let tailWidth: CGFloat
        let text: String
        let font: UIFont
        let textInsets: UIEdgeInsets
        let preferredMaxLayoutWidth: CGFloat
    }
    
    let layoutContext: LayoutContext
    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }
    
    func calculateLayout() {
        let iconSize = CGSize(width: 24, height: 12)
        let margin: CGFloat = 10
        let textHorizontalInset = self.layoutContext.textInsets.bma_horziontalInset
        let maxTextWidth = self.layoutContext.preferredMaxLayoutWidth - textHorizontalInset - iconSize.width - margin
        let textSize = self.textSizeThatFitsWidth(maxTextWidth)
        
        let width = textSize.width + margin + iconSize.width + textHorizontalInset + layoutContext.tailWidth
        let bubbleSize = CGSize(width: width, height: 40)
        self.bubbleFrame = CGRect(origin: .zero, size: bubbleSize)
        
        let iconX = layoutContext.contentInsets.left + (layoutContext.isIncoming ? layoutContext.tailWidth : 0)
        let iconY = (bubbleSize.height - iconSize.height) / 2.0
        self.iconFrame = CGRect(origin: CGPoint(x: iconX, y: iconY), size: iconSize)
        self.durationFrame = CGRect(origin: CGPoint(x: iconX + iconSize.width + margin, y: (bubbleSize.height - textSize.height) / 2.0), size: textSize)
        
        self.size = bubbleSize
    }
    
    private func textSizeThatFitsWidth(_ width: CGFloat) -> CGSize {
        let textContainer: NSTextContainer = {
            let size = CGSize(width: width, height: .greatestFiniteMagnitude)
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            return container
        }()
        
        let textStorage = self.replicateUITextViewNSTextStorage()
        let layoutManager: NSLayoutManager = {
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            return layoutManager
        }()
        
        let rect = layoutManager.usedRect(for: textContainer)
        return rect.size.bma_round()
    }
    
    private func replicateUITextViewNSTextStorage() -> NSTextStorage {
        // See https://github.com/badoo/Chatto/issues/129
        return NSTextStorage(string: self.layoutContext.text, attributes: [
            NSAttributedString.Key.font: self.layoutContext.font,
            NSAttributedString.Key(rawValue: "NSOriginalFont"): self.layoutContext.font
            ])
    }
}
