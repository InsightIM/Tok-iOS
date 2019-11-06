//
//  FileMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class FileMessageCollectionViewCell: BaseMessageCollectionViewCell<FileBubbleView> {
    static func sizingCell() -> FileMessageCollectionViewCell {
        let cell = FileMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    override func createBubbleView() -> FileBubbleView {
        return FileBubbleView()
    }
    
    override var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = viewContext
        }
    }
    
    var viewModel: FileMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.cellAccessibilityIdentifier
            self.messageViewModel = viewModel
            self.bubbleView.viewModel = viewModel
        }
    }
    
    var style: FileBubbleViewStyle! {
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
