//
//  AudioMessageHandler.swift
//  Tok
//
//  Created by Bryce on 2019/6/28.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions

class AudioMessageHandler: BaseMessageHandler {

    override func userDidTapOnBubble(viewModel: MessageViewModelProtocol) {
        guard let viewModel = viewModel as? AudioMessageViewModel,
            let model = viewModel.messageModel as? AudioMessageModel else {
            return
        }
        
        if viewModel.isIncoming, viewModel.status != .success {
            return
        }
        
        if viewModel.unread.value {
            viewModel.unread.value = false
            dataSource.setAudioAsReaded(id: viewModel.messageModel.uid)
        }
        
        guard let path = viewModel.filePath else {
            return
        }
        
        let node = AudioManager.Node(message: model, path: path)
        AudioManager.shared.playOrStop(node: node)
    }
}
