//
//  AudioMessageCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2019/5/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions

class AudioMessageCollectionViewCell: BaseMessageCollectionViewCell<AudioBubbleView> {
    static func sizingCell() -> AudioMessageCollectionViewCell {
        let cell = AudioMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    override func createBubbleView() -> AudioBubbleView {
        return AudioBubbleView()
    }
    
    override var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = viewContext
        }
    }
    
    var viewModel: AudioMessageViewModel! {
        didSet {
            self.accessibilityIdentifier = self.viewModel.cellAccessibilityIdentifier
            self.messageViewModel = viewModel
            self.bubbleView.viewModel = viewModel
            AudioManager.shared.register(cell: self, forMessageId: viewModel.messageModel.uid)
        }
    }
    
    var style: AudioBubbleViewStyle! {
        didSet {
            self.bubbleView.messageStyle = style
        }
    }
    
    override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
        }, animated: animated, completion: completion)
    }
    
    var layoutCache: NSCache<AnyObject, AnyObject>! {
        didSet {
            self.bubbleView.layoutCache = self.layoutCache
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        bubbleView.isPlaying = false
        AudioManager.shared.unregister(cell: self, forMessageId: viewModel.messageModel.uid)
    }
    
    deinit {
        AudioManager.shared.unregister(cell: self, forMessageId: viewModel.messageModel.uid)
    }
}
