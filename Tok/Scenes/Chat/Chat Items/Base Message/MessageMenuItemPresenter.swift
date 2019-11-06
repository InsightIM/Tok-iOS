//
//  MessageMenuItemPresenter.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions

protocol UIMenuItemHandlerProtocol {
    func userDidTapOnCopyMenuItem(viewModel: MessageViewModelProtocol)
    func userDidTapOnForwardMenuItem(viewModel: MessageViewModelProtocol)
    func userDidTapOnDeleteMenuItem(viewModel: MessageViewModelProtocol)
}

class MessageMenuItemPresenter: ChatItemMenuPresenterProtocol {
    
    // MARK: - Private properties
    
    private let viewModel: MessageViewModelProtocol
    private let menuHandler: UIMenuItemHandlerProtocol?
    
    // MARK: - Instantiation
    
    public init(viewModel: MessageViewModelProtocol, menuHandler: UIMenuItemHandlerProtocol?) {
        self.viewModel = viewModel
        self.menuHandler = menuHandler
    }
    
    static func setupCustomMenus() {
        let forwardMenu = UIMenuItem(title: NSLocalizedString("Forward", comment: ""), action: #selector(UICollectionViewCell.forward(_:)))
        let deleteMenu = UIMenuItem(title: NSLocalizedString("Delete", comment: ""), action: #selector(UICollectionViewCell.deleteMessage(_:)))
        UIMenuController.shared.menuItems = [forwardMenu, deleteMenu]
    }
    
    // MARK: - ChatItemMenuPresenterProtocol
    
    public func shouldShowMenu() -> Bool {
        return true
    }
    
    public func canPerformMenuControllerAction(_ action: Selector) -> Bool {
        return action == .copy || action == .forward || action == .delete
    }
    
    public func performMenuControllerAction(_ action: Selector) {
        switch action {
        case .copy:
            menuHandler?.userDidTapOnCopyMenuItem(viewModel: viewModel)
        case .forward:
            menuHandler?.userDidTapOnForwardMenuItem(viewModel: viewModel)
        case .delete:
            menuHandler?.userDidTapOnDeleteMenuItem(viewModel: viewModel)
        default:
            break
        }
    }
}

extension UICollectionViewCell {
    @objc
    func forward(_ sender: Any?) {
        if let collectionView = self.superview as? UICollectionView {
            if let indexPath = collectionView.indexPath(for: self) {
                // Trigger action
                collectionView.delegate?.collectionView?(collectionView, performAction: #selector(UICollectionViewCell.forward(_:)), forItemAt: indexPath, withSender: sender)
            }
        }
    }
    
    @objc
    func deleteMessage(_ sender: Any?) {
        if let collectionView = self.superview as? UICollectionView {
            if let indexPath = collectionView.indexPath(for: self) {
                // Trigger action
                collectionView.delegate?.collectionView?(collectionView, performAction: #selector(UICollectionViewCell.deleteMessage(_:)), forItemAt: indexPath, withSender: sender)
            }
        }
    }
}

extension Selector {
    static var copy: Selector {
        return #selector(UIResponderStandardEditActions.copy(_:))
    }
    static var delete: Selector {
        return #selector(UICollectionViewCell.deleteMessage(_:))
    }
    static var forward: Selector {
        return #selector(UICollectionViewCell.forward(_:))
    }
}
