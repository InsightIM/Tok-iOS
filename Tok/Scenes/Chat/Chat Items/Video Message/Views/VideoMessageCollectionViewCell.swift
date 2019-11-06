//
//  VideoMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class VideoMessageCollectionViewCell: BaseMessageCollectionViewCell<VideoBubbleView> {
    static func sizingCell() -> VideoMessageCollectionViewCell {
        let cell = VideoMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    override func createBubbleView() -> VideoBubbleView {
        return VideoBubbleView()
    }
    
    override var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = viewContext
        }
    }
    
    var viewModel: VideoMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.cellAccessibilityIdentifier
            self.messageViewModel = viewModel
            self.bubbleView.videoMessageViewModel = viewModel
        }
    }
    
    var style: VideoBubbleViewStyle! {
        didSet {
            self.bubbleView.videoMessageStyle = style
        }
    }
    
    override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
        }, animated: animated, completion: completion)
    }
}
