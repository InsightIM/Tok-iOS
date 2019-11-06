//
//  TextMessageViewModelBuilder.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

class TextMessageViewModelBuilder: ViewModelBuilderProtocol {
    
    let messageViewModelBuilder: MessageViewModelDefaultBuilder
    init(_ messageViewModelBuilder: MessageViewModelDefaultBuilder) {
        self.messageViewModelBuilder = messageViewModelBuilder
    }
    
    func createViewModel(_ textMessage: TextMessageModel) -> TextMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(textMessage)
        let textMessageViewModel = TextMessageViewModel(messageModel: textMessage, messageViewModel: messageViewModel)
        return textMessageViewModel
    }
    
    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is TextMessageModel
    }
}
