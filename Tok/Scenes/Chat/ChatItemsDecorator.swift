/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import Foundation
import Chatto
import ChattoAdditions

final class ChatItemsDecorator: ChatItemsDecoratorProtocol {
    private struct Constants {
        static let shortSeparation: CGFloat = 3
        static let normalSeparation: CGFloat = 15
        static let timeIntervalThresholdToIncreaseSeparation: TimeInterval = 120
    }

    private let messagesSelector: MessagesSelector
    private let showTopLabel: Bool
    private let isGroup: Bool
    init(messagesSelector: MessagesSelector, isGroup: Bool) {
        self.messagesSelector = messagesSelector
        self.isGroup = isGroup
        self.showTopLabel = isGroup
    }

    func decorateItems(_ chatItems: [ChatItemProtocol]) -> [DecoratedChatItem] {
        var decoratedChatItems = [DecoratedChatItem]()
        
        for (index, chatItem) in chatItems.enumerated() {
            let next: ChatItemProtocol? = (index + 1 < chatItems.count) ? chatItems[index + 1] : nil
            let prev: ChatItemProtocol? = (index > 0) ? chatItems[index - 1] : nil

            let bottomMargin = self.separationAfterItem(chatItem, next: next)
            var showsTail = true
            let additionalItems = [DecoratedChatItem]()
            var addTimeSeparator = false
            var isSelected = false
            var isShowingSelectionIndicator = false
            var showName = false

            if let currentMessage = chatItem as? MessageModelProtocol {
                showsTail = currentMessage.type == TextMessageModel.chatItemType
                    || currentMessage.type == AudioMessageModel.chatItemType
                    || currentMessage.type == FileMessageModel.chatItemType
                
                showName = currentMessage.isIncoming ? showTopLabel : false

                if prev is SystemMessageModel {
                    addTimeSeparator = true
                } else if let previousMessage = prev as? MessageModelProtocol {
                    addTimeSeparator = currentMessage.date.timeIntervalSince(previousMessage.date) > Constants.timeIntervalThresholdToIncreaseSeparation
                } else {
                    addTimeSeparator = false
                }

//                if self.showsStatusForMessage(currentMessage) {
//                    additionalItems.append(
//                        DecoratedChatItem(
//                            chatItem: SendingStatusModel(uid: "\(currentMessage.uid)-decoration-status", status: currentMessage.status),
//                            decorationAttributes: nil)
//                    )
//                }

                if addTimeSeparator {
                    let dateTimeStamp = DecoratedChatItem(chatItem: TimeSeparatorModel(uid: "\(currentMessage.uid)-time-separator", date: MessageDateFormatter.shared.string(from: currentMessage.date)), decorationAttributes: nil)
                    decoratedChatItems.append(dateTimeStamp)
                }

                isSelected = self.messagesSelector.isMessageSelected(currentMessage)
                isShowingSelectionIndicator = self.messagesSelector.isActive && self.messagesSelector.canSelectMessage(currentMessage)
            }
            
            let messageDecorationAttributes = BaseMessageDecorationAttributes(
                canShowFailedIcon: canShowFailedIcon(item: chatItem),
                isShowingTail: showsTail,
                isShowingAvatar: true,
                isShowingSelectionIndicator: isShowingSelectionIndicator,
                isSelected: isSelected,
                isShowingTopLabel: showName
            )

            decoratedChatItems.append(
                DecoratedChatItem(
                    chatItem: chatItem,
                    decorationAttributes: ChatItemDecorationAttributes(bottomMargin: bottomMargin, messageDecorationAttributes: messageDecorationAttributes)
                )
            )
            decoratedChatItems.append(contentsOf: additionalItems)
        }

        return decoratedChatItems
    }
    
    private func canShowFailedIcon(item: ChatItemProtocol) -> Bool {
        guard let item = item as? MessageModelProtocol, item.status == .failed else {
            return false
        }
        
        if let current = item as? RenewableType {
            return current.renewable == false
        }
        
        return true
    }

    private func separationAfterItem(_ current: ChatItemProtocol?, next: ChatItemProtocol?) -> CGFloat {
        guard next != nil else { return 0 }
        if current is SystemMessageModel { return 0 }
        
        return Constants.normalSeparation
        
//        guard let currentMessage = current as? MessageModelProtocol else { return Constants.normalSeparation }
//        guard let nextMessage = nexItem as? MessageModelProtocol else { return Constants.normalSeparation }
//
//        if currentMessage.senderId != nextMessage.senderId {
//            return Constants.normalSeparation
//        } else if nextMessage.date.timeIntervalSince(currentMessage.date) > Constants.timeIntervalThresholdToIncreaseSeparation {
//            return Constants.normalSeparation
//        } else {
//            return Constants.shortSeparation
//        }
    }
}
