//
//  TextMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/15.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

final class TextMessageCollectionViewCell: BaseMessageCollectionViewCell<TextBubbleView> {
    
    public static func sizingCell() -> TextMessageCollectionViewCell {
        let cell = TextMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    // MARK: Subclassing (view creation)
    
    public override func createBubbleView() -> TextBubbleView {
        return TextBubbleView()
    }
    
    public override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
        }, animated: animated, completion: completion)
    }
    
    // MARK: Property forwarding
    
    override public var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = self.viewContext
        }
    }
    
    public var textMessageViewModel: TextMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.textMessageViewModel.cellAccessibilityIdentifier
            self.messageViewModel = self.textMessageViewModel
            self.bubbleView.textMessageViewModel = self.textMessageViewModel
        }
    }
    
    public var textMessageStyle: TextMessageStyle! {
        didSet {
            self.bubbleView.style = self.textMessageStyle
        }
    }
    
    override public var isSelected: Bool {
        didSet {
            self.bubbleView.selected = self.isSelected
        }
    }
    
    public var layoutCache: NSCache<AnyObject, AnyObject>! {
        didSet {
            self.bubbleView.layoutCache = self.layoutCache
        }
    }
}
