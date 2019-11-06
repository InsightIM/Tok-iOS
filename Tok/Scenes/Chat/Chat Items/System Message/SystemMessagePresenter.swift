//
//  SystemMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/6/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

protocol SystemMessageHandler: class {
    func userDidTapOnBubble()
}

class SystemMessagePresenter: ChatItemPresenterProtocol {
    var isItemUpdateSupported: Bool = false
    
    func update(with chatItem: ChatItemProtocol) {
    }
    
    let model: SystemMessageModel
    weak var interactionHandler: SystemMessageHandler?
    init (model: SystemMessageModel) {
        self.model = model
    }
    
    static func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(SystemMessageCollectionViewCell.self, forCellWithReuseIdentifier: "SystemMessageCollectionViewCell")
    }
    
    func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "SystemMessageCollectionViewCell", for: indexPath)
    }
    
    func configureCell(_ cell: UICollectionViewCell, decorationAttributes: ChatItemDecorationAttributesProtocol?) {
        guard let systemCell = cell as? SystemMessageCollectionViewCell else {
            assert(false, "expecting status cell")
            return
        }
        
        systemCell.text = self.model.text
        systemCell.hiddenLock = self.model.isGroup
        systemCell.didTapBubbleView = self.model.isGroup ? nil : { [weak self] in
            self?.interactionHandler?.userDidTapOnBubble()
        }
    }
    
    var canCalculateHeightInBackground: Bool {
        return true
    }
    
    func heightForCell(maximumWidth width: CGFloat, decorationAttributes: ChatItemDecorationAttributesProtocol?) -> CGFloat {
        let attributedText = NSAttributedString(string: model.text, attributes: [.font: UIFont.systemFont(ofSize: 12)])
        let messageContainerSize = labelSize(for: attributedText, considering: width - 40)
        return messageContainerSize.height + 20 + (decorationAttributes?.bottomMargin ?? 0)
    }
    
    func labelSize(for attributedText: NSAttributedString, considering maxWidth: CGFloat) -> CGSize {
        let constraintBox = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let rect = attributedText.boundingRect(with: constraintBox, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).integral
        
        return rect.size
    }
}

class SystemMessagePresenterBuilder: ChatItemPresenterBuilderProtocol {
    weak var interactionHandler: SystemMessageHandler?
    
    func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        return createPresenter(chatItem, interactionHandler: interactionHandler)
    }
    
    func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return chatItem is SystemMessageModel
    }
    
    func createPresenter(_ chatItem: ChatItemProtocol, interactionHandler: SystemMessageHandler?) -> ChatItemPresenterProtocol {
        assert(self.canHandleChatItem(chatItem))
        let presenter = SystemMessagePresenter(model: chatItem as! SystemMessageModel)
        presenter.interactionHandler = interactionHandler
        return presenter
    }
    
    var presenterType: ChatItemPresenterProtocol.Type {
        return SystemMessagePresenter.self
    }
}
