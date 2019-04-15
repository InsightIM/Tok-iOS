//
//  FileMessageSizeCalculator.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

open class FileMessageSizeCalculator: MessageSizeCalculator {
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        guard let message = message as? MessageModel else {
            return .zero
        }
        
        switch message.kind {
        case .file:
            return CGSize(width: 220, height: 70)
        default:
            return .zero
        }
    }
}
