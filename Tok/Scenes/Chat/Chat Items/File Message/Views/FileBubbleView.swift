//
//  FileBubbleView.swift
//  Tok
//
//  Created by Bryce on 2019/6/6.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class FileBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {

    public var viewContext: ViewContext = .normal
    public var animationDuration: CFTimeInterval = 0.33
    public var preferredMaxLayoutWidth: CGFloat = 0
    public var didTapOperationButton: (() -> Void)?
    
    let font = UIFont.systemFont(ofSize: 15)
    
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
        addSubview(nameLabel)
        addSubview(bottomLabel)
        addSubview(extenView)
        extenView.addSubview(extenLabel)
        addSubview(progressIndicatorView)
        progressIndicatorView.addTarget(self, action: #selector(self.handleDidTapOperationButton), for: .touchUpInside)
    }
    
    @objc
    private func handleDidTapOperationButton() {
        didTapOperationButton?()
    }
    
    private lazy var overlayView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.accessibilityIdentifier = "chatto.message.file.image.bubble"
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.lineBreakMode = .byTruncatingMiddle
        label.font = font
        return label
    }()
    
    private lazy var bottomLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#B8B8B8")
        label.font = UIFont.systemFont(ofSize: 13)
        return label
    }()
    
    private lazy var extenView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.image = UIImage(named: "FiletypeDefault")
        return view
    }()
    
    private lazy var extenLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 15)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private(set) var progressIndicatorView: NetworkOperationButton = {
        return NetworkOperationButton(type: .custom)
    }()
    
    var selected: Bool = false {
        didSet {
            if self.selected != oldValue {
                self.updateViews()
            }
        }
    }
    
    var messageStyle: FileBubbleViewStyle! {
        didSet {
            self.updateViews()
        }
    }
    
    public var viewModel: FileMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.bubbleAccessibilityIdentifier
            self.updateViews()

            viewModel.updateProgress = { [weak self] progress -> Void in
                self?.updateProgressIndicator(progress)
            }
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
        nameLabel.text = viewModel.fileName
        bottomLabel.text = viewModel.fileSize
        extenLabel.text = viewModel.fileExtension
    }
    
    private func updateImages() {
        let bubbleImage = messageStyle.bubbleImage(viewModel: self.viewModel, isSelected: selected)
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
        
        if let overlayColor = messageStyle.overlayColor(viewModel: self.viewModel) {
            self.overlayView.backgroundColor = overlayColor
            self.overlayView.alpha = 1
            if self.overlayView.superview == nil {
                extenView.addSubview(self.overlayView)
            }
        } else {
            self.overlayView.alpha = 0
        }
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
        progressIndicatorView.center = extenView.center
        extenView.bma_rect = layout.extenFrame
        extenLabel.bma_rect = layout.extenLabelFrame
        nameLabel.bma_rect = layout.nameFrame
        bottomLabel.bma_rect = layout.fileSizeFrame
        bubbleImageView.bma_rect = layout.bubbleFrame
        bubbleImageView.layer.mask?.frame = bubbleImageView.layer.bounds
        overlayView.bma_rect = extenView.bounds
    }
    
    private func calculateBubbleLayout(maximumWidth: CGFloat) -> FileBubbleLayoutModel {
        let layoutContext = FileBubbleLayoutModel.LayoutContext(isIncoming: viewModel.isIncoming,
                                                                contentInsets: messageStyle.contentInsets(viewModel: viewModel),
                                                                tailWidth: messageStyle.tailWidth(viewModel: viewModel),
                                                                text: viewModel.fileName,
                                                                font: font,
                                                                textInsets: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 10),
                                                                preferredMaxLayoutWidth: preferredMaxLayoutWidth)
        
        let layoutModel = FileBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        
        return layoutModel
    }
    
    open var canCalculateSizeInBackground: Bool {
        return true
    }
}

private class FileBubbleLayoutModel {
    var bubbleFrame: CGRect = .zero
    var nameFrame: CGRect = .zero
    var fileSizeFrame: CGRect = .zero
    var extenFrame: CGRect = .zero
    var extenLabelFrame: CGRect = .zero
    var visualCenter: CGPoint = .zero
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
        let extenSize = CGSize(width: 50, height: 56)
        let margin: CGFloat = 8.0
        
        let textHorizontalInset = self.layoutContext.textInsets.bma_horziontalInset
        let maxTextWidth = self.layoutContext.preferredMaxLayoutWidth - textHorizontalInset - extenSize.width - margin
        let textSize = self.textSizeThatFitsWidth(maxTextWidth)
        
        let bubbleWidth = textSize.width + margin + extenSize.width + textHorizontalInset + layoutContext.tailWidth
        let bubbleSize = CGSize(width: max(bubbleWidth, 200), height: 70)
        self.bubbleFrame = CGRect(origin: .zero, size: bubbleSize)
        let offsetX: CGFloat = 0.5 * self.layoutContext.tailWidth * (self.layoutContext.isIncoming ? 1.0 : -1.0)
        self.visualCenter = self.bubbleFrame.bma_center.bma_offsetBy(dx: offsetX, dy: 0)
        
        let extenX = layoutContext.contentInsets.left + (layoutContext.isIncoming ? layoutContext.tailWidth : 0)
        let extenY = (bubbleSize.height - extenSize.height) / 2.0
        self.extenFrame = CGRect(origin: CGPoint(x: extenX, y: extenY), size: extenSize)
        
        let labelY = extenSize.height - 15 - 6
        self.extenLabelFrame = CGRect(origin: CGPoint(x: 2, y: labelY), size: CGSize(width: extenSize.width - 12, height: 15))
        
        let fileNameHeight: CGFloat = 18.0
        let origin = extenFrame.offsetBy(dx: extenSize.width + 6, dy: (extenSize.height - margin) / 2.0 - fileNameHeight).origin
        let width = bubbleSize.width - origin.x - layoutContext.contentInsets.right - (layoutContext.isIncoming ? 0 : layoutContext.tailWidth)
        self.nameFrame = CGRect(origin: origin, size: CGSize(width: width, height: fileNameHeight))
        self.fileSizeFrame = self.nameFrame.offsetBy(dx: 0, dy: self.nameFrame.height + margin)
        
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
