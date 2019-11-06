//
//  AudioBubbleView.swift
//  Tok
//
//  Created by Bryce on 2019/5/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class AudioBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {

    public var viewContext: ViewContext = .normal
    public var animationDuration: CFTimeInterval = 0.33
    public var preferredMaxLayoutWidth: CGFloat = 0
    public var didTapOperationButton: (() -> Void)?
    
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
        addSubview(waveImageView)
        addSubview(lengthLabel)
        addSubview(statusImageView)
        addSubview(progressIndicatorView)
        addSubview(unreadImageView)
        progressIndicatorView.addTarget(self, action: #selector(self.handleDidTapOperationButton), for: .touchUpInside)
    }
    
    @objc
    private func handleDidTapOperationButton() {
        didTapOperationButton?()
    }
    
    private lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.accessibilityIdentifier = "chatto.message.audio.image.bubble"
        return imageView
    }()
    
    lazy var waveImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.tokBlack
        imageView.animationDuration = 1.0
        return imageView
    }()
    
    lazy var statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var unreadImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var lengthLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    public private(set) var progressIndicatorView: NetworkOperationButton = {
        return NetworkOperationButton(type: .custom)
    }()
    
    public var selected: Bool = false {
        didSet {
            if self.selected != oldValue {
                self.updateViews()
            }
        }
    }
    
    public var isPlaying: Bool = false {
        didSet {
            guard self.isPlaying != oldValue else {
                return
            }
            
            if isPlaying {
                waveImageView.startAnimating()
            } else {
                waveImageView.stopAnimating()
            }
        }
    }
    
    public var viewModel: AudioMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.bubbleAccessibilityIdentifier
            self.updateViews()
            
            viewModel.updateProgress = { [weak self] (progress) -> Void in
                self?.updateProgressIndicator(progress)
            }
        }
    }
    
    var messageStyle: AudioBubbleViewStyle! {
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
        self.updateProgressIndicator(0)
        self.updateImages()
        self.setNeedsLayout()
    }
    
    private func updateText() {
        self.lengthLabel.text = viewModel.text
    }
    
    private func updateImages() {
        let bubbleImage = messageStyle.bubbleImage(viewModel: self.viewModel, isSelected: selected)
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
        
        let statusImage = messageStyle.bubbleStatusImage(viewModel: self.viewModel)
        if self.statusImageView.image != statusImage { self.statusImageView.image = statusImage }
        
        let audioImage = messageStyle.audioImage(viewModel: self.viewModel)
        if self.waveImageView.image != audioImage { self.waveImageView.image = audioImage }
        
        let animationImages = messageStyle.animationImages(viewModel: viewModel)
        if waveImageView.animationImages != animationImages { waveImageView.animationImages = animationImages }
        
        bubbleImageView.layer.mask = UIImageView(image: messageStyle.maskingImage(viewModel: viewModel)).layer
        
        unreadImageView.image = messageStyle.unreadImage(viewModel: viewModel)
    }
    
    private func updateProgressIndicator(_ progress: Double) {
        let transferStatus = self.viewModel.transferStatus
        let transferProgress = progress
        
        let style: NetworkOperationButton.Style = {
            switch transferStatus {
            case .idle:
                return viewModel.isIncoming ? .download: .upload
            case .failed:
                if viewModel.renewable {
                    return viewModel.isIncoming ? .download : .upload
                }
                return .finished(showPlayIcon: false)
            case .transfering:
                return .busy(progress: transferProgress)
            case .success, .expired:
                return .finished(showPlayIcon: false)
            }
        }()
        
        self.progressIndicatorView.style = style
    }
    
    // MARK: Layout
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateBubbleLayout(maximumWidth: size.width).size
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        let layout = calculateBubbleLayout(maximumWidth: preferredMaxLayoutWidth)
        progressIndicatorView.size = NetworkOperationButton.buttonSize
        progressIndicatorView.center = layout.visualCenter
        waveImageView.bma_rect = layout.imageFrame
        statusImageView.bma_rect = layout.statusFrame
        lengthLabel.bma_rect = layout.durationFrame
        bubbleImageView.bma_rect = layout.bubbleFrame
        bubbleImageView.layer.mask?.frame = bubbleImageView.layer.bounds
        unreadImageView.bma_rect = layout.unreadDotFrame
    }
    
    public var layoutCache: NSCache<AnyObject, AnyObject>!
    private func calculateBubbleLayout(maximumWidth: CGFloat) -> AudioBubbleLayoutModel {
        let layoutContext = AudioBubbleLayoutModel.LayoutContext(isIncoming: viewModel.isIncoming,
                                                                 duration: viewModel.duration,
                                                                 imageSize: CGSize(width: 12, height: 16),
                                                                 text: viewModel.text,
                                                                 font: messageStyle.textFont(viewModel: viewModel),
                                                                 preferredMaxLayoutWidth: maximumWidth,
                                                                 contentInsets: messageStyle.contentInsets(viewModel: viewModel),
                                                                 tailWidth: messageStyle.tailWidth(viewModel: viewModel))
        
        if let layoutModel = self.layoutCache.object(forKey: layoutContext.hashValue as AnyObject) as? AudioBubbleLayoutModel, layoutModel.layoutContext == layoutContext {
            return layoutModel
        }
        
        let layoutModel = AudioBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        
        self.layoutCache.setObject(layoutModel, forKey: layoutContext.hashValue as AnyObject)
        return layoutModel
    }
    
    open var canCalculateSizeInBackground: Bool {
        return true
    }
}

private class AudioBubbleLayoutModel {
    var bubbleFrame: CGRect = .zero
    var imageFrame: CGRect = .zero
    var statusFrame: CGRect = .zero
    var durationFrame: CGRect = .zero
    var unreadDotFrame: CGRect = .zero
    var visualCenter: CGPoint = .zero
    var size: CGSize = CGSize.zero
    
    struct LayoutContext: Equatable, Hashable {
        let isIncoming: Bool
        let duration: UInt
        let imageSize: CGSize
        let text: String
        let font: UIFont
        let preferredMaxLayoutWidth: CGFloat
        let contentInsets: UIEdgeInsets
        let tailWidth: CGFloat
    }
    
    let layoutContext: LayoutContext
    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }
    
    func calculateLayout() {
        let bubbleSize = bubbleSizeThatFitsDuration(layoutContext.duration)
        self.bubbleFrame = CGRect(origin: .zero, size: bubbleSize)
        let offsetX: CGFloat = 0.5 * self.layoutContext.tailWidth * (self.layoutContext.isIncoming ? 1.0 : -1.0)
        self.visualCenter = self.bubbleFrame.bma_center.bma_offsetBy(dx: offsetX, dy: 0)
        
        let x = layoutContext.isIncoming
            ? layoutContext.contentInsets.left
            : bubbleSize.width - layoutContext.contentInsets.right - 14
        self.statusFrame = CGRect(x: x, y: bubbleSize.height - self.layoutContext.contentInsets.bottom - 15, width: 10, height: 10)
        
        let imageX = layoutContext.isIncoming
            ? bubbleSize.width - layoutContext.contentInsets.right - layoutContext.imageSize.width
            : layoutContext.contentInsets.left
        let imageY = (bubbleSize.height - layoutContext.imageSize.height) / 2.0
        imageFrame = CGRect(origin: CGPoint(x: imageX, y: imageY), size: layoutContext.imageSize)
        
        let maxTextWidth = self.layoutContext.preferredMaxLayoutWidth
        let textSize = self.textSizeThatFitsWidth(maxTextWidth)
        let origin = layoutContext.isIncoming
            ? imageFrame.offsetBy(dx: -textSize.width - 5, dy: 0).origin
            : imageFrame.offsetBy(dx: imageFrame.width + 5, dy: 0).origin
        self.durationFrame = CGRect(origin: origin, size: textSize)
        
        let unreadSize = CGSize(width: 10, height: 10)
        unreadDotFrame = CGRect(origin: CGPoint(x: bubbleSize.width + layoutContext.tailWidth, y: (bubbleSize.height - unreadSize.height) / 2.0), size: unreadSize)
        self.size = bubbleSize
    }
    
    private func bubbleSizeThatFitsDuration(_ duration: UInt) -> CGSize {
        let width = Waveform.estimatedWidth(forDurationInSeconds: duration)
        return CGSize(width: width, height: 38)
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

struct Waveform {
    static let minCount: UInt = 30
    static let maxCount: UInt = UIScreen.main.bounds.width > 320.1 ? 63 : 50
    static let minDuration: UInt = 1
    static let maxDuration: UInt = 60
    static let slope = Float(maxCount - minCount) / Float(maxDuration - minDuration)
    static let intercept = Float(minCount) - Float(minDuration) * slope
    private static let barWidth: CGFloat = 2
    
    static func numberOfValues(forDurationInSeconds duration: UInt) -> Int {
        return Int(round(Waveform.slope * Float(duration) + Waveform.intercept))
    }
    
    static func estimatedWidth(forDurationInSeconds duration: UInt) -> CGFloat {
        let duration = max(Waveform.minDuration, min(Waveform.maxDuration, duration))
        let numberOfBars = Waveform.numberOfValues(forDurationInSeconds: duration)
        return 1.5 * barWidth * CGFloat(numberOfBars)
    }
}
