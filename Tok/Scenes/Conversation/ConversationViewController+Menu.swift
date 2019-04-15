//
//  ConversationViewController+Menu.swift
//  Tok
//
//  Created by Bryce on 2019/1/21.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

extension ConversationViewController {
    func setupMenus() {
        let forwardMenu = UIMenuItem(title: NSLocalizedString("Forward", comment: ""), action: #selector(MessageCollectionViewCell.forward))
        let deleteMenu = UIMenuItem(title: NSLocalizedString("Delete", comment: ""), action: #selector(MessageCollectionViewCell.deleteMessage))
        UIMenuController.shared.menuItems = [forwardMenu, deleteMenu]
    }
}

extension MessageCollectionViewCell {
    @objc func forward(_ sender: Any?) {
        if let collectionView = self.superview as? UICollectionView {
            if let indexPath = collectionView.indexPath(for: self) {
                // Trigger action
                collectionView.delegate?.collectionView?(collectionView, performAction: #selector(MessageCollectionViewCell.forward(_:)), forItemAt: indexPath, withSender: sender)
            }
        }
    }
    
    @objc func deleteMessage(_ sender: Any?) {
        if let collectionView = self.superview as? UICollectionView {
            if let indexPath = collectionView.indexPath(for: self) {
                // Trigger action
                collectionView.delegate?.collectionView?(collectionView, performAction: #selector(MessageCollectionViewCell.deleteMessage(_:)), forItemAt: indexPath, withSender: sender)
            }
        }
    }
}
