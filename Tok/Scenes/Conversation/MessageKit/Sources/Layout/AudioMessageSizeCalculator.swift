//
//  AudioMessageSizeCalculator.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

open class AudioMessageSizeCalculator: MessageSizeCalculator {
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        guard let message = message as? MessageModel else { return .zero }
        
        switch message.kind {
        case .audio(let item):
            let width = item.contentWidth
            return CGSize(width: width, height: 38)
        default:
            return .zero
        }
    }
}
