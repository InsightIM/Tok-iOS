//
//  PhotoMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/6/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class PhotoMessageCollectionViewCell: BaseMessageCollectionViewCell<PhotoBubbleView> {
    
    static func sizingCell() -> PhotoMessageCollectionViewCell {
        let cell = PhotoMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    public override func createBubbleView() -> PhotoBubbleView {
        return PhotoBubbleView()
    }
    
    override public var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = self.viewContext
        }
    }
    
    public var photoMessageViewModel: PhotoMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.photoMessageViewModel.cellAccessibilityIdentifier
            self.messageViewModel = self.photoMessageViewModel
            self.bubbleView.photoMessageViewModel = self.photoMessageViewModel
        }
    }
    
    public var photoMessageStyle: PhotoMessageStyle! {
        didSet {
            self.bubbleView.photoMessageStyle = self.photoMessageStyle
        }
    }
    
    public override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
        }, animated: animated, completion: completion)
    }
}
