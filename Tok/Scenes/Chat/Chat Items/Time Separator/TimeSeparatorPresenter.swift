//
//  TimeSeparatorPresenter.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto

class TimeSeparatorPresenter: ChatItemPresenterProtocol {
    var isItemUpdateSupported: Bool = false
    
    func update(with chatItem: ChatItemProtocol) {
    }
    
    let timeSeparatorModel: TimeSeparatorModel
    init (timeSeparatorModel: TimeSeparatorModel) {
        self.timeSeparatorModel = timeSeparatorModel
    }
    
    private static let cellReuseIdentifier = TimeSeparatorCollectionViewCell.self.description()
    
    static func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(TimeSeparatorCollectionViewCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
    }
    
    func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: TimeSeparatorPresenter.cellReuseIdentifier, for: indexPath)
    }
    
    func configureCell(_ cell: UICollectionViewCell, decorationAttributes: ChatItemDecorationAttributesProtocol?) {
        guard let timeSeparatorCell = cell as? TimeSeparatorCollectionViewCell else {
            assert(false, "expecting status cell")
            return
        }
        
        timeSeparatorCell.text = self.timeSeparatorModel.date
    }
    
    var canCalculateHeightInBackground: Bool {
        return true
    }
    
    func heightForCell(maximumWidth width: CGFloat, decorationAttributes: ChatItemDecorationAttributesProtocol?) -> CGFloat {
        return 34
    }
}
