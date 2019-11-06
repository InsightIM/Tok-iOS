//
//  CallMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class CallMessageCollectionViewCell: BaseMessageCollectionViewCell<CallBubbleView> {
    static func sizingCell() -> CallMessageCollectionViewCell {
        let cell = CallMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    override func createBubbleView() -> CallBubbleView {
        return CallBubbleView()
    }
    
    override var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = viewContext
        }
    }
    
    var viewModel: CallMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.cellAccessibilityIdentifier
            self.messageViewModel = viewModel
            self.bubbleView.viewModel = viewModel
        }
    }
    
    var style: CallBubbleViewStyle! {
        didSet {
            self.bubbleView.messageStyle = style
        }
    }
    
    override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
        }, animated: animated, completion: completion)
    }
}
