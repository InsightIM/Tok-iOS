//
//  GenericMessageHandler.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

final class GenericMessageHandler<ViewModel: MessageViewModelProtocol>: BaseMessageInteractionHandlerProtocol, FileOperationHandlerProtocol, UIMenuItemHandlerProtocol, DetectedStringHandlerProtocol {
    
    private let baseHandler: BaseMessageHandler
    
    init(baseHandler: BaseMessageHandler) {
        self.baseHandler = baseHandler
    }
    
    func userDidTapOnFailIcon(viewModel: ViewModel, failIconView: UIView) {
        self.baseHandler.userDidTapOnFailIcon(viewModel: viewModel)
    }
    
    func userDidTapOnAvatar(viewModel: ViewModel) {
        self.baseHandler.userDidTapOnAvatar(viewModel: viewModel)
    }
    
    func userDidBeginLongPressOnAvatar(viewModel: ViewModel) {
        self.baseHandler.userDidBeginLongPressOnAvatar(viewModel: viewModel)
    }

    func userDidEndLongPressOnAvatar(viewModel: ViewModel) {
        self.baseHandler.userDidEndLongPressOnAvatar(viewModel: viewModel)
    }
    
    func userDidTapOnBubble(viewModel: ViewModel) {
        self.baseHandler.userDidTapOnBubble(viewModel: viewModel)
    }
    
    func userDidBeginLongPressOnBubble(viewModel: ViewModel) {
        self.baseHandler.userDidBeginLongPressOnBubble(viewModel: viewModel)
    }
    
    func userDidEndLongPressOnBubble(viewModel: ViewModel) {
        self.baseHandler.userDidEndLongPressOnBubble(viewModel: viewModel)
    }
    
    func userDidSelectMessage(viewModel: ViewModel) {
        self.baseHandler.userDidSelectMessage(viewModel: viewModel)
    }
    
    func userDidDeselectMessage(viewModel: ViewModel) {
        self.baseHandler.userDidDeselectMessage(viewModel: viewModel)
    }
    
    func messageWillBeShown(viewModel: ViewModel) {
        self.baseHandler.messageWillBeShown(viewModel: viewModel)
    }
    
    func userDidTapOnOperationButton(viewModel: ViewModel) {
        self.baseHandler.userDidTapOnOperationButton(viewModel: viewModel)
    }
    
    func userDidTapOnCopyMenuItem(viewModel: MessageViewModelProtocol) {
        self.baseHandler.userDidTapOnCopyMenuItem(viewModel: viewModel)
    }
    
    func userDidTapOnForwardMenuItem(viewModel: MessageViewModelProtocol) {
        self.baseHandler.userDidTapOnForwardMenuItem(viewModel: viewModel)
    }
    
    func userDidTapOnDeleteMenuItem(viewModel: MessageViewModelProtocol) {
        self.baseHandler.userDidTapOnDeleteMenuItem(viewModel: viewModel)
    }
    
    func userDidTapOnDetectedString(text: String, detectedDataType: DetectedDataType, viewModel: MessageViewModelProtocol) {
        self.baseHandler.userDidTapOnDetectedString(text: text, detectedDataType: detectedDataType, viewModel: viewModel)
    }
}
