//
//  SystemMessageSizeCalculator.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

open class SystemMessageSizeCalculator: MessageSizeCalculator {
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        let width = layout?.collectionView?.frame.width ?? UIScreen.main.bounds.width
        
        guard let message = message as? MessageModel else {
            return .zero
        }
        
        switch message.kind {
        case .system(let text):
            let attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 12)])
            let messageContainerSize = labelSize(for: attributedText, considering: width - 20 - 14 - 8)
            return CGSize(width: width, height: messageContainerSize.height + 20)
        default:
            return .zero
        }
    }
}
