//
//  FileMessageHandler.swift
//  Tok
//
//  Created by Bryce on 2019/7/18.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

protocol FileMessageHandlerDelegate: class {
    func openDocumentAction(filePath: String, name: String?)
}

class FileMessageHandler: BaseMessageHandler {
    weak var delegate: FileMessageHandlerDelegate?
    
    override func userDidTapOnBubble(viewModel: MessageViewModelProtocol) {
        guard viewModel is FileMessageViewModel,
        let model = viewModel.messageModel as? FileMessageModel,
        let filePath = model.filePath else {
            return
        }
        
        delegate?.openDocumentAction(filePath: filePath, name: model.fileName)
    }
}
