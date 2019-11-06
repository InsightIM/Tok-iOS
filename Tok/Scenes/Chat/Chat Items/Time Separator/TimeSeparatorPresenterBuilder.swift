//
//  TimeSeparatorPresenterBuilder.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto

class TimeSeparatorPresenterBuilder: ChatItemPresenterBuilderProtocol {
    func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return chatItem is TimeSeparatorModel
    }
    
    func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        assert(self.canHandleChatItem(chatItem))
        return TimeSeparatorPresenter(timeSeparatorModel: chatItem as! TimeSeparatorModel)
    }
    
    var presenterType: ChatItemPresenterProtocol.Type {
        return TimeSeparatorPresenter.self
    }
}
