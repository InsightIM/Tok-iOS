//
//  PhotoMessageViewModelBuilder.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

class PhotoMessageViewModelBuilder: ViewModelBuilderProtocol {

    let messageViewModelBuilder: MessageViewModelDefaultBuilder
    init(_ messageViewModelBuilder: MessageViewModelDefaultBuilder) {
        self.messageViewModelBuilder = messageViewModelBuilder
    }
    
    func createViewModel(_ model: PhotoMessageModel) -> PhotoMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let photoMessageViewModel = PhotoMessageViewModel(messageModel: model, messageViewModel: messageViewModel)
        return photoMessageViewModel
    }
    
    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is PhotoMessageModel
    }
}
