//
//  CallMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

class CallMessageViewModel: DecoratedMessageViewModelProtocol {
    let messageModel: MessageModelProtocol
    let messageViewModel: MessageViewModelProtocol
    
    let cellAccessibilityIdentifier = "chatto.message.call.cell"
    let bubbleAccessibilityIdentifier = "chatto.message.call.bubble"
    
    let text: String
    
    init(messageModel: CallMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.messageModel = messageModel
        self.messageViewModel = messageViewModel
        
        let duration = NSLocalizedString("Duration:", comment: "")
        let durationText = "\(duration) \(String(timeInterval: messageModel.duration))"
        if messageModel.isIncoming {
            text = messageModel.answered ? durationText : NSLocalizedString("Missed call", comment: "")
        } else {
            text = messageModel.answered ? durationText : NSLocalizedString("Unanswered call", comment: "")
        }
    }
    
    func willBeShown() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
    
    func wasHidden() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
}

class CallMessageViewModelBuilder: ViewModelBuilderProtocol {
    typealias ModelT = CallMessageModel
    typealias ViewModelT = CallMessageViewModel
    
    let messageViewModelBuilder: MessageViewModelDefaultBuilder
    init(_ messageViewModelBuilder: MessageViewModelDefaultBuilder) {
        self.messageViewModelBuilder = messageViewModelBuilder
    }
    
    func createViewModel(_ model: CallMessageModel) -> CallMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let callMessageViewModel = CallMessageViewModel(messageModel: model, messageViewModel: messageViewModel)
        return callMessageViewModel
    }
    
    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is CallMessageModel
    }
}
