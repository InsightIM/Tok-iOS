//
//  TextBubbleView.swift
//  Tok
//
//  Created by Bryce on 2019/7/15.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

final class TextBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
    
    public var preferredMaxLayoutWidth: CGFloat = 0
    public var animationDuration: CFTimeInterval = 0.33
    public var viewContext: ViewContext = .normal {
        didSet {
            if self.viewContext == .sizing {
                self.textView.dataDetectorTypes = UIDataDetectorTypes()
                self.textView.isSelectable = false
            } else {
                self.textView.dataDetectorTypes = .all
                self.textView.isSelectable = true
            }
        }
    }
    
    public var style: TextMessageStyle! {
        didSet {
            self.updateViews()
        }
    }
    
    public var textMessageViewModel: TextMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.textMessageViewModel.bubbleAccessibilityIdentifier
            self.updateViews()
        }
    }
    
    public var selected: Bool = false {
        didSet {
            if self.selected != oldValue {
                self.updateViews()
            }
        }
    }
    
    public var tapDetectedStringAction: ((String, DetectedDataType) -> Void)? = nil {
        didSet {
            textView.tapDetectedStringAction = tapDetectedStringAction
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    private func commonInit() {
        self.addSubview(self.bubbleImageView)
        self.addSubview(self.textView)
        self.addSubview(self.statusImageView)
    }
    
    private lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.addSubview(self.borderImageView)
        imageView.accessibilityIdentifier = "chatto.message.text.image.bubble"
        return imageView
    }()
    
    private var borderImageView: UIImageView = UIImageView()
    private lazy var textView: ChatMessageTextView = {
        let textView = ChatMessageTextView()
        UIView.performWithoutAnimation({ () -> Void in // fixes iOS 8 blinking when cell appears
            textView.backgroundColor = UIColor.clear
        })
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .all
        textView.scrollsToTop = false
        textView.isScrollEnabled = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.isExclusiveTouch = true
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }()
    
    private var statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
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
        guard let style = self.style else { return }
        
        self.updateTextView()
        let bubbleImage = style.bubbleImage(viewModel: self.textMessageViewModel, isSelected: self.selected)
        let borderImage = style.bubbleImageBorder(viewModel: self.textMessageViewModel, isSelected: self.selected)
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
        if self.borderImageView.image != borderImage { self.borderImageView.image = borderImage }
        
        let statusImage = style.bubbleStatusImage(viewModel: self.textMessageViewModel)
        if self.statusImageView.image != statusImage { self.statusImageView.image = statusImage }
    }
    
    private func updateTextView() {
        guard let style = self.style, let viewModel = self.textMessageViewModel else { return }
        
        let font = style.textFont(viewModel: viewModel, isSelected: selected)
        let textColor = style.textColor(viewModel: viewModel, isSelected: selected)
        let linkColor = style.linkTextColor(viewModel: viewModel, isSelected: selected)
        
        var needsToUpdateText = false
        
        if self.textView.font != font {
            self.textView.font = font
            needsToUpdateText = true
        }
        
        if self.textView.textColor != textColor {
            self.textView.textColor = textColor
            self.textView.linkTextAttributes = [
                NSAttributedString.Key.foregroundColor: linkColor,
                NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            needsToUpdateText = true
        }
        
        if needsToUpdateText || self.textView.text != viewModel.text {
            self.textView.text = viewModel.text
        }
        
        let textInsets = style.textInsets(viewModel: viewModel, isSelected: self.selected)
        if self.textView.textContainerInset != textInsets { self.textView.textContainerInset = textInsets }
    }
    
    private func bubbleImage() -> UIImage {
        return self.style.bubbleImage(viewModel: self.textMessageViewModel, isSelected: self.selected)
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateTextBubbleLayout(preferredMaxLayoutWidth: size.width).size
    }
    
    // MARK: Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        let layout = self.calculateTextBubbleLayout(preferredMaxLayoutWidth: self.preferredMaxLayoutWidth)
        self.textView.bma_rect = layout.textFrame
        self.bubbleImageView.bma_rect = layout.bubbleFrame
        self.borderImageView.bma_rect = self.bubbleImageView.bounds
        self.statusImageView.bma_rect = layout.statusFrame
    }
    
    public var layoutCache: NSCache<AnyObject, AnyObject>!
    private func calculateTextBubbleLayout(preferredMaxLayoutWidth: CGFloat) -> TextBubbleLayoutModel {
        let layoutContext = TextBubbleLayoutModel.LayoutContext(
            text: self.textMessageViewModel.text,
            font: self.style.textFont(viewModel: self.textMessageViewModel, isSelected: self.selected),
            textInsets: self.style.textInsets(viewModel: self.textMessageViewModel, isSelected: self.selected),
            preferredMaxLayoutWidth: preferredMaxLayoutWidth
        )
        
        if let layoutModel = self.layoutCache.object(forKey: layoutContext.hashValue as AnyObject) as? TextBubbleLayoutModel, layoutModel.layoutContext == layoutContext {
            return layoutModel
        }
        
        let layoutModel = TextBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        
        self.layoutCache.setObject(layoutModel, forKey: layoutContext.hashValue as AnyObject)
        return layoutModel
    }
    
    public var canCalculateSizeInBackground: Bool {
        return true
    }
}

private final class TextBubbleLayoutModel {
    let layoutContext: LayoutContext
    var textFrame: CGRect = CGRect.zero
    var bubbleFrame: CGRect = CGRect.zero
    var statusFrame: CGRect = CGRect.zero
    var size: CGSize = CGSize.zero
    
    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }
    
    struct LayoutContext: Equatable, Hashable {
        let text: String
        let font: UIFont
        let textInsets: UIEdgeInsets
        let preferredMaxLayoutWidth: CGFloat
    }
    
    func calculateLayout() {
        let textHorizontalInset = self.layoutContext.textInsets.bma_horziontalInset
        let maxTextWidth = self.layoutContext.preferredMaxLayoutWidth - textHorizontalInset
        let textSize = self.textSizeThatFitsWidth(maxTextWidth)
        let bubbleSize = textSize.bma_outsetBy(dx: textHorizontalInset, dy: self.layoutContext.textInsets.bma_verticalInset)
        self.bubbleFrame = CGRect(origin: CGPoint.zero, size: bubbleSize)
        self.textFrame = self.bubbleFrame
        self.statusFrame = CGRect(x: bubbleSize.width - self.layoutContext.textInsets.right + 10, y: bubbleSize.height - self.layoutContext.textInsets.bottom - 5, width: 10, height: 10)
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

/// UITextView with hacks to avoid selection, loupe, define...
private final class ChatMessageTextView: UITextView {
    
    override var canBecomeFirstResponder: Bool {
        return false
    }
    
    // See https://github.com/badoo/Chatto/issues/363
    override var gestureRecognizers: [UIGestureRecognizer]? {
        set {
            super.gestureRecognizers = newValue
        }
        get {
            return super.gestureRecognizers?.filter { gestureRecognizer in
                if #available(iOS 13, *) {
                    return !ChatMessageTextView.notAllowedGestureRecognizerNames.contains(gestureRecognizer.name?.base64String ?? "")
                }
                if #available(iOS 11, *),
                    gestureRecognizer.name?.base64String == SystemGestureRecognizerNames.linkTap.rawValue {
                    return true
                }
                return type(of: gestureRecognizer) == UILongPressGestureRecognizer.self
                && gestureRecognizer.delaysTouchesEnded
            }
//            return super.gestureRecognizers?.filter({ (gestureRecognizer) -> Bool in
//                return type(of: gestureRecognizer) == UITapGestureRecognizer.self
//                    || type(of: gestureRecognizer) == UILongPressGestureRecognizer.self && gestureRecognizer.delaysTouchesEnded
//            })
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
    
    override var selectedRange: NSRange {
        get {
            return NSRange(location: 0, length: 0)
        }
        set {
            // Part of the heaviest stack trace when scrolling (when updating text)
            // See https://github.com/badoo/Chatto/pull/144
        }
    }
    
    override var contentOffset: CGPoint {
        get {
            return .zero
        }
        set {
            // Part of the heaviest stack trace when scrolling (when bounds are set)
            // See https://github.com/badoo/Chatto/pull/144
        }
    }
    
    // Handle Detected String
    
    var tapDetectedStringAction: ((String, DetectedDataType) -> Void)?
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        self.delegate = self
    }
    
    override var text: String! {
        didSet {
            let attributedString = NSMutableAttributedString(string: text)
            
            let textRange = NSMakeRange(0, (text as NSString).length)
            
            attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor!, range: textRange)
            attributedString.addAttribute(NSAttributedString.Key.font, value: font!, range: textRange)
            
            DetectedDataType.allCases.forEach { detectionType in
                let pattern = detectionType.rawValue
                let expression = try! NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options())
                
                expression.enumerateMatches(in: text, options: NSRegularExpression.MatchingOptions(), range: textRange) {  result, flags, stop in
                    if let result = result {
                        let textValue = (self.text as NSString).substring(with: result.range)
                        
                        let textAttributes: [NSAttributedString.Key : Any]! = [NSAttributedString.Key.foregroundColor: UIColor.blue, NSAttributedString.Key.link: textValue, NSAttributedString.Key(rawValue: detectionType.rawValue): detectionType.rawValue]
                        
                        attributedString.addAttributes(textAttributes, range: result.range)
                    }
                }
            }
            self.attributedText = attributedString
        }
    }
    
    fileprivate func disableDragInteraction() {
        if #available(iOS 11.0, *) {
            self.textDragInteraction?.isEnabled = false
        }
    }
    
    fileprivate func disableLargeContentViewer() {
        #if compiler(>=5.1)
        if #available(iOS 13.0, *) {
            self.showsLargeContentViewer = false
        }
        #endif
    }
    
    private static let notAllowedGestureRecognizerNames: Set<String> = Set([
        SystemGestureRecognizerNames.forcePress.rawValue,
        SystemGestureRecognizerNames.loupe.rawValue,
    ])
}

private enum SystemGestureRecognizerNames: String {
    // _UIKeyboardTextSelectionGestureForcePress
    case forcePress = "X1VJS2V5Ym9hcmRUZXh0U2VsZWN0aW9uR2VzdHVyZUZvcmNlUHJlc3M="
    // UITextInteractionNameLoupe
    case loupe = "VUlUZXh0SW50ZXJhY3Rpb25OYW1lTG91cGU="
    // UITextInteractionNameLinkTap
    case linkTap = "VUlUZXh0SW50ZXJhY3Rpb25OYW1lTGlua1RhcA=="
    // UITextInteractionNameSingleTap
    case singleTap = "VUlUZXh0SW50ZXJhY3Rpb25OYW1lU2luZ2xlVGFw"
}

private extension String {
    var base64String: String? {
        return self.data(using: .utf8)?.base64EncodedString()
    }
}

extension ChatMessageTextView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL?, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard interaction == .invokeDefaultAction else {
            return true // TODO: Custom
        }
        let findDetectionType = DetectedDataType.allCases.first(where: {
            textView.attributedText.attribute(NSAttributedString.Key($0.rawValue), at: characterRange.location, effectiveRange: nil) != nil
        })
        
        guard let detectionType = findDetectionType else {
            return true
        }
        
        let text = (self.text as NSString).substring(with: characterRange)
        if text.isNotEmpty {
            tapDetectedStringAction?(text, detectionType)
        }
        return false
    }
}
