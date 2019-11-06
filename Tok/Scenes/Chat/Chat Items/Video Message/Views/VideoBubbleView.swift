//
//  VideoBubbleView.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class VideoBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
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
        autoresizesSubviews = false
        addSubview(imageView)
        addSubview(durationLabel)
        addSubview(placeholderIconView)
        addSubview(progressIndicatorView)
        progressIndicatorView.addTarget(self, action: #selector(self.handleDidTapOperationButton), for: .touchUpInside)
    }
    
    @objc
    private func handleDidTapOperationButton() {
        didTapOperationButton?()
    }
    
    public private(set) lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.autoresizingMask = []
        imageView.clipsToBounds = true
        imageView.autoresizesSubviews = false
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    lazy var durationLabel: InsetLabel = {
        let label = InsetLabel()
        label.layer.backgroundColor = UIColor("#1E1E1E").withAlphaComponent(0.4).cgColor
        label.textColor = .white
        label.font = .systemFont(ofSize: 11)
        label.numberOfLines = 1
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        return label
    }()
    
    public private(set) var progressIndicatorView: NetworkOperationButton = {
        return NetworkOperationButton(type: .custom)
    }()
    
    private var placeholderIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.autoresizingMask = []
        return imageView
    }()
    
    public var videoMessageViewModel: VideoMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.videoMessageViewModel.bubbleAccessibilityIdentifier
            self.updateViews()

            videoMessageViewModel.updateProgress = { [weak self] (progress) -> Void in
                self?.updateProgressIndicator(progress)
            }
        }
    }
    
    public var videoMessageStyle: VideoBubbleViewStyle! {
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
        guard videoMessageViewModel != nil, videoMessageStyle != nil else { return }
        
        updateText()
        updateProgressIndicator(0)
        updateImages()
        setNeedsLayout()
    }
    
    private func updateText() {
        let isIncoming = videoMessageViewModel.isIncoming
        let renewable = videoMessageViewModel.renewable
        let transferStatus = videoMessageViewModel.transferStatus
        let failed = transferStatus == .failed
        
        switch (isIncoming, renewable, failed) {
        case (true, false, true):
            durationLabel.isHidden = true
        default:
            durationLabel.isHidden = false
        }
        durationLabel.text = transferStatus == .success
            ? videoMessageViewModel.duration
            : videoMessageViewModel.fileSize
    }
    
    private func updateProgressIndicator(_ progress: Double) {
        let transferStatus = self.videoMessageViewModel.transferStatus
        let transferProgress = progress
        
        let style: NetworkOperationButton.Style = {
            switch transferStatus {
            case .idle:
                return videoMessageViewModel.isIncoming ? .download: .upload
            case .failed:
                if videoMessageViewModel.renewable {
                    return videoMessageViewModel.isIncoming ? .download : .upload
                }
                return .finished(showPlayIcon: !videoMessageViewModel.isIncoming)
            case .transfering:
                return .busy(progress: transferProgress)
            case .success:
                return .finished(showPlayIcon: true)
            case .expired:
                return .expired
            }
        }()
        
        if transferStatus == .transfering, case .busy(let progress) = self.progressIndicatorView.style, progress >= transferProgress {
            return
        }
        self.progressIndicatorView.style = style
    }
    
    private func updateImages() {
        self.placeholderIconView.image = self.videoMessageStyle.placeholderIconImage(viewModel: self.videoMessageViewModel)
        self.placeholderIconView.tintColor = self.videoMessageStyle.placeholderIconTintColor(viewModel: self.videoMessageViewModel)
        
        if let image = self.videoMessageViewModel.image.value {
            self.imageView.image = image
            self.placeholderIconView.isHidden = true
        } else {
            self.imageView.image = self.videoMessageStyle.placeholderBackgroundImage(viewModel: self.videoMessageViewModel)
            self.placeholderIconView.isHidden = self.videoMessageViewModel.transferStatus == .success
        }
        
        self.imageView.layer.mask = UIImageView(image: self.videoMessageStyle.maskingImage(viewModel: self.videoMessageViewModel)).layer
    }
    
    // MARK: Layout
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateTextBubbleLayout(maximumWidth: size.width).size
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        let layout = self.calculateTextBubbleLayout(maximumWidth: self.preferredMaxLayoutWidth)
        self.progressIndicatorView.size = NetworkOperationButton.buttonSize
        self.progressIndicatorView.center = layout.visualCenter
        self.placeholderIconView.center = layout.visualCenter
        self.placeholderIconView.bounds = CGRect(origin: .zero, size: layout.placeholderFrame.size)
        self.imageView.bma_rect = layout.photoFrame
        self.imageView.layer.mask?.frame = self.imageView.layer.bounds
        self.durationLabel.sizeToFit()
        let x = layout.photoFrame.width - durationLabel.size.width - 6 - (videoMessageViewModel.isIncoming ? 0 : layout.layoutContext.tailWidth)
        let y = layout.photoFrame.height - self.durationLabel.size.height - 6
        self.durationLabel.frame = CGRect(origin: CGPoint(x: x, y: y), size: durationLabel.size)
    }
    
    private func calculateTextBubbleLayout(maximumWidth: CGFloat) -> VideoBubbleLayoutModel {
        let layoutContext = VideoBubbleLayoutModel.LayoutContext(messageViewModel: videoMessageViewModel, style: videoMessageStyle, containerWidth: maximumWidth)
        let layoutModel = VideoBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        return layoutModel
    }
    
    open var canCalculateSizeInBackground: Bool {
        return true
    }
    
}

private class VideoBubbleLayoutModel {
    var photoFrame: CGRect = .zero
    var placeholderFrame: CGRect = .zero
    var visualCenter: CGPoint = .zero // Because image is cropped a few points on the side of the tail, the apparent center will be a bit shifted
    var size: CGSize = .zero
    
    struct LayoutContext {
        let photoSize: CGSize
        let placeholderSize: CGSize
        let preferredMaxLayoutWidth: CGFloat
        let isIncoming: Bool
        let tailWidth: CGFloat
        
        init(photoSize: CGSize,
             placeholderSize: CGSize,
             tailWidth: CGFloat,
             isIncoming: Bool,
             preferredMaxLayoutWidth width: CGFloat) {
            self.photoSize = photoSize
            self.placeholderSize = placeholderSize
            self.tailWidth = tailWidth
            self.isIncoming = isIncoming
            self.preferredMaxLayoutWidth = width
        }
        
        init(messageViewModel model: VideoMessageViewModel,
             style: VideoBubbleViewStyle,
             containerWidth width: CGFloat) {
            self.init(photoSize: style.bubbleSize(viewModel: model),
                      placeholderSize: style.placeholderIconImage(viewModel: model).size,
                      tailWidth: style.tailWidth(viewModel: model),
                      isIncoming: model.isIncoming,
                      preferredMaxLayoutWidth: width)
        }
    }
    
    let layoutContext: LayoutContext
    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }
    
    func calculateLayout() {
        let photoSize = self.layoutContext.photoSize
        self.photoFrame = CGRect(origin: .zero, size: photoSize)
        self.placeholderFrame = CGRect(origin: .zero, size: self.layoutContext.placeholderSize)
        let offsetX: CGFloat = 0.5 * self.layoutContext.tailWidth * (self.layoutContext.isIncoming ? 1.0 : -1.0)
        self.visualCenter = self.photoFrame.bma_center.bma_offsetBy(dx: offsetX, dy: 0)
        self.size = photoSize
    }
}
