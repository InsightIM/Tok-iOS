//
//  BaseMessageHandler.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions

open class BaseMessageHandler {
    let dataSource: ConversationDataSource
    let messagesSelector: MessagesSelector
    weak var parentViewController: UIViewController?
    
    init(dataSource: ConversationDataSource, messagesSelector: MessagesSelector, parentViewController: UIViewController) {
        self.dataSource = dataSource
        self.messagesSelector = messagesSelector
        self.parentViewController = parentViewController
    }
    
    open func userDidTapOnFailIcon(viewModel: MessageViewModelProtocol) {
        guard viewModel.status == .failed else {
            return
        }
        
        let deleteAction: AlertViewManager.Action = { [weak self] in
            if viewModel.messageModel.uid == AudioManager.shared.playingNode?.message.uid {
                AudioManager.shared.stop(deactivateAudioSession: true)
            }
            self?.dataSource.deleteMessage(id: viewModel.messageModel.uid)
        }
        
        if viewModel.isIncoming {
            AlertViewManager.showActionSheet(with: [
                (NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)
                ])
        } else {
            let resendAction: AlertViewManager.Action = { [weak self] in
                self?.dataSource.resend(message: viewModel.messageModel)
            }
            
            AlertViewManager.showActionSheet(with: [
                (NSLocalizedString("Resend", comment: ""), .default, resendAction),
                (NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)
                ])
        }
    }
    
    open func userDidTapOnAvatar(viewModel: MessageViewModelProtocol) {
        guard viewModel.isIncoming else {
            let vc = ProfileViewController(messageService: dataSource.messageService)
            parentViewController?.navigationController?.pushViewController(vc, animated: true)
            return
        }
        let senderId = viewModel.messageModel.senderId
        let viewController = FriendViewController(messageService: dataSource.messageService, publicKey: senderId, chat: dataSource.chat)
        parentViewController?.navigationController?.pushViewController(viewController, animated: true)
    }
    
    open func userDidTapOnBubble(viewModel: MessageViewModelProtocol) {
        if viewModel is CallMessageViewModel {
            NotificationCenter.default.post(name: NSNotification.Name.StartVoiceCall, object: nil, userInfo: ["chat": self.dataSource.chat])
        }
    }
    
    open func userDidBeginLongPressOnBubble(viewModel: MessageViewModelProtocol) {
        print("userDidBeginLongPressOnBubble")
    }
    
    open func userDidEndLongPressOnBubble(viewModel: MessageViewModelProtocol) {
        print("userDidEndLongPressOnBubble")
    }
    
    open func userDidSelectMessage(viewModel: MessageViewModelProtocol) {
        print("userDidSelectMessage")
        self.messagesSelector.selectMessage(viewModel.messageModel)
    }
    
    open func userDidDeselectMessage(viewModel: MessageViewModelProtocol) {
        print("userDidDeselectMessage")
        self.messagesSelector.deselectMessage(viewModel.messageModel)
    }
    
    open func messageWillBeShown(viewModel: MessageViewModelProtocol) {
        dataSource.markMessageAsRead(id: viewModel.messageModel.uid)
    }
    
    open func userDidTapOnOperationButton(viewModel: MessageViewModelProtocol) {
        guard let viewModel = viewModel as? FileTransferViewModelPorotocol & DecoratedMessageViewModelProtocol,
            let model = viewModel.messageModel as? TransferProgressHanlder else {
            return
        }
        
        let isIncoming = viewModel.isIncoming
        switch model.transferStatus {
        case .idle:
            if isIncoming {
                dataSource.resume(id: viewModel.messageModel.uid)
            } else {
                dataSource.resend(message: viewModel.messageModel)
            }
        case .transfering:
            dataSource.cancelFileMessage(id: viewModel.messageModel.uid, isIncoming: isIncoming)
        default:
            return
        }
    }
    
    func userDidTapOnCopyMenuItem(viewModel: MessageViewModelProtocol) {
        guard let viewModel = viewModel as? TextMessageViewModel else {
            return
        }
        UIPasteboard.general.string = viewModel.text
    }
    
    func userDidTapOnForwardMenuItem(viewModel: MessageViewModelProtocol) {
        let viewModel = ForwardMessageViewModel(messageId: viewModel.messageModel.uid, messageService: dataSource.messageService)
        let vc = ForwardChatViewController(viewModel: viewModel)
        let nav = UINavigationController(rootViewController: vc)
        parentViewController?.present(nav, animated: true, completion: nil)
    }
    
    func userDidTapOnDeleteMenuItem(viewModel: MessageViewModelProtocol) {
        dataSource.deleteMessage(id: viewModel.messageModel.uid)
    }
    
    func userDidTapOnDetectedString(text: String, detectedDataType: DetectedDataType, viewModel: MessageViewModelProtocol) {
    }
    
    func userDidBeginLongPressOnAvatar(viewModel: MessageViewModelProtocol) {
        
    }
    
    func userDidEndLongPressOnAvatar(viewModel: MessageViewModelProtocol) {
        guard viewModel.isIncoming else {
            return
        }
        let name = dataSource.messageService.nameManager.name(by: viewModel.messageModel.senderId)
        guard name.isNotEmpty else {
            return
        }
        let info = dataSource.chat.isGroup ? "@" + name : name
        dataSource.longPressAvatar.onNext(info)
    }
}
