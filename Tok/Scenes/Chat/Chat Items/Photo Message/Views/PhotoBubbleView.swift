//
//  PhotoBubbleView.swift
//  Tok
//
//  Created by Bryce on 2019/6/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions
import YYImage

final class PhotoBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
    
    public var viewContext: ViewContext = .normal
    public var animationDuration: CFTimeInterval = 0.33
    public var preferredMaxLayoutWidth: CGFloat = 0
    public var didTapOperationButton: (() -> Void)?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        autoresizesSubviews = false
        addSubview(imageView)
        addSubview(placeholderIconView)
        addSubview(sizeLabel)
        addSubview(progressIndicatorView)
        
        progressIndicatorView.addTarget(self, action: #selector(self.handleDidTapOperationButton), for: .touchUpInside)
    }
    
    @objc
    private func handleDidTapOperationButton() {
        didTapOperationButton?()
    }
    
    public private(set) lazy var imageView: UIImageView = {
        let imageView = YYAnimatedImageView()
        imageView.autoresizingMask = []
        imageView.clipsToBounds = true
        imageView.autoresizesSubviews = false
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    public private(set) var progressIndicatorView: NetworkOperationButton = {
        return NetworkOperationButton(type: .custom)
    }()
    
    private var placeholderIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.autoresizingMask = []
        return imageView
    }()
    
    lazy var sizeLabel: InsetLabel = {
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
    
    public var photoMessageViewModel: PhotoMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.photoMessageViewModel.bubbleAccessibilityIdentifier
            self.updateViews()
            
            photoMessageViewModel.updateProgress = { [weak self] (progress) -> Void in
                self?.updateProgressIndicator(progress)
            }
        }
    }
    
    public var photoMessageStyle: PhotoMessageStyle! {
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
    
    private func updateViews() {
        if self.viewContext == .sizing { return }
        if isUpdating { return }
        guard self.photoMessageViewModel != nil, self.photoMessageStyle != nil else { return }
        
        updateText()
        updateProgressIndicator(0)
        updateImages()
        setNeedsLayout()
    }
    
    private func updateText() {
        let transferStatus = photoMessageViewModel.transferStatus
        
        sizeLabel.text = photoMessageViewModel.fileSize
        sizeLabel.isHidden = transferStatus == .success
    }
    
    private func updateProgressIndicator(_ progress: Double) {
        let transferStatus = self.photoMessageViewModel.transferStatus
        let transferProgress = progress
        
        let style: NetworkOperationButton.Style = {
            switch transferStatus {
            case .idle:
                return photoMessageViewModel.isIncoming ? .download: .upload
            case .failed:
                if photoMessageViewModel.renewable {
                    return photoMessageViewModel.isIncoming ? .download : .upload
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
    
    private func updateImages() {
        self.placeholderIconView.image = self.photoMessageStyle.placeholderIconImage(viewModel: self.photoMessageViewModel)
        self.placeholderIconView.tintColor = self.photoMessageStyle.placeholderIconTintColor(viewModel: self.photoMessageViewModel)
        
        if let image = self.photoMessageViewModel.image.value {
            self.imageView.image = image
            self.placeholderIconView.isHidden = true
        } else {
            self.imageView.image = self.photoMessageStyle.placeholderBackgroundImage(viewModel: self.photoMessageViewModel)
            self.placeholderIconView.isHidden = self.photoMessageViewModel.transferStatus == .success
        }
        self.imageView.layer.mask = UIImageView(image: self.photoMessageStyle.maskingImage(viewModel: self.photoMessageViewModel)).layer
    }
    
    // MARK: Layout
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateTextBubbleLayout(maximumWidth: size.width).size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let layout = calculateTextBubbleLayout(maximumWidth: preferredMaxLayoutWidth)
        progressIndicatorView.size = NetworkOperationButton.buttonSize
        progressIndicatorView.center = layout.visualCenter
        placeholderIconView.center = layout.visualCenter
        placeholderIconView.bounds = CGRect(origin: .zero, size: layout.placeholderFrame.size)
        imageView.bma_rect = layout.photoFrame
        imageView.layer.mask?.frame = imageView.layer.bounds
        sizeLabel.sizeToFit()
        let x = layout.photoFrame.width - sizeLabel.size.width - 6 - (photoMessageViewModel.isIncoming ? 0 : layout.layoutContext.tailWidth)
        let y = layout.photoFrame.height - sizeLabel.size.height - 6
        sizeLabel.frame = CGRect(origin: CGPoint(x: x, y: y), size: sizeLabel.size)
    }
    
    private func calculateTextBubbleLayout(maximumWidth: CGFloat) -> PhotoBubbleLayoutModel {
        let layoutContext = PhotoBubbleLayoutModel.LayoutContext(photoMessageViewModel: photoMessageViewModel, style: photoMessageStyle, containerWidth: maximumWidth)
        let layoutModel = PhotoBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        return layoutModel
    }
    
    var canCalculateSizeInBackground: Bool {
        return true
    }
    
}

private class PhotoBubbleLayoutModel {
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
        
        init(photoMessageViewModel model: PhotoMessageViewModel,
             style: PhotoMessageStyle,
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

