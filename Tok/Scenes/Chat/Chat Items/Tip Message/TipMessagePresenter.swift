//
//  TipMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/6/19.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto

class TipMessagePresenter: ChatItemPresenterProtocol {
    var isItemUpdateSupported: Bool = false
    
    func update(with chatItem: ChatItemProtocol) {
    }
    
    let model: TipMessageModel
    init (model: TipMessageModel) {
        self.model = model
    }
    
    private static let cellReuseIdentifier = TipMessageCollectionViewCell.self.description()
    
    static func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(TipMessageCollectionViewCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
    }
    
    func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: TipMessagePresenter.cellReuseIdentifier, for: indexPath)
    }
    
    func configureCell(_ cell: UICollectionViewCell, decorationAttributes: ChatItemDecorationAttributesProtocol?) {
        guard let tipCell = cell as? TipMessageCollectionViewCell else {
            assert(false, "expecting status cell")
            return
        }
        
        tipCell.text = self.model.text
    }
    
    var canCalculateHeightInBackground: Bool {
        return true
    }
    
    func heightForCell(maximumWidth width: CGFloat, decorationAttributes: ChatItemDecorationAttributesProtocol?) -> CGFloat {
        return 30
    }
}

class TipMessagePresenterBuilder: ChatItemPresenterBuilderProtocol {
    func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return chatItem is TipMessageModel
    }
    
    func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        assert(self.canHandleChatItem(chatItem))
        return TipMessagePresenter(model: chatItem as! TipMessageModel)
    }
    
    var presenterType: ChatItemPresenterProtocol.Type {
        return TipMessagePresenter.self
    }
}
