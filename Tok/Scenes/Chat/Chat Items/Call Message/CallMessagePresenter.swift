//
//  CallMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

class CallMessagePresenter<ViewModelBuilderT, InteractionHandlerT>: BaseMessagePresenter<CallBubbleView, ViewModelBuilderT, InteractionHandlerT> where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == CallMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & UIMenuItemHandlerProtocol,
InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    private var menuPresenter: ChatItemMenuPresenterProtocol?
    let layoutCache: NSCache<AnyObject, AnyObject>
    let callCellStyle: CallBubbleViewStyle
    init (
        messageModel: ModelT,
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: CallMessageCollectionViewCell,
        baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
        callCellStyle: CallBubbleViewStyle,
        layoutCache: NSCache<AnyObject, AnyObject>) {
        self.layoutCache = layoutCache
        self.callCellStyle = callCellStyle
        super.init(
            messageModel: messageModel,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            cellStyle: baseCellStyle
        )
    }
    
    final override class func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(CallMessageCollectionViewCell.self, forCellWithReuseIdentifier: "Call-message")
    }
    
    final override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Call-message", for: indexPath)
    }
    
    override func createViewModel() -> CallMessageViewModel {
        let viewModel = self.viewModelBuilder.createViewModel(self.messageModel)
        self.menuPresenter = CallMessageMenuItemPresenter(viewModel: viewModel, menuHandler: interactionHandler)
        let updateClosure = { [weak self] (old: Any, new: Any) -> Void in
            self?.updateCurrentCell()
        }
        viewModel.avatarImage.observe(self, closure: updateClosure)
        return viewModel
    }
    
    override func configureCell(_ cell: BaseMessageCollectionViewCell<CallBubbleView>, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? CallMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }
        
        super.configureCell(cell, decorationAttributes: decorationAttributes, animated: animated) { () -> Void in
            cell.viewModel = self.messageViewModel
            cell.style = self.callCellStyle
            additionalConfiguration?()
        }
    }
    
    var CallCell: CallMessageCollectionViewCell? {
        if let cell = self.cell {
            if let CallCell = cell as? CallMessageCollectionViewCell {
                return CallCell
            } else {
                assert(false, "Invalid cell was given to presenter!")
            }
        }
        return nil
    }
    
    func updateCurrentCell() {
        if let cell = self.CallCell, let decorationAttributes = self.decorationAttributes {
            self.configureCell(cell, decorationAttributes: decorationAttributes, animated: self.itemVisibility != .appearing, additionalConfiguration: nil)
        }
    }
    
    open override func canShowMenu() -> Bool {
        return self.menuPresenter?.shouldShowMenu() ?? false
    }
    
    open override func canPerformMenuControllerAction(_ action: Selector) -> Bool {
        return self.menuPresenter?.canPerformMenuControllerAction(action) ?? false
    }
    
    open override func performMenuControllerAction(_ action: Selector) {
        self.menuPresenter?.performMenuControllerAction(action)
    }
}

class CallMessagePresenterBuilder<ViewModelBuilderT, InteractionHandlerT>: ChatItemPresenterBuilderProtocol where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == CallMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & UIMenuItemHandlerProtocol,
InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    
    typealias ModelT = ViewModelBuilderT.ModelT
    typealias ViewModelT = ViewModelBuilderT.ViewModelT
    
    let layoutCache = NSCache<AnyObject, AnyObject>()
    init(
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?) {
        self.viewModelBuilder = viewModelBuilder
        self.interactionHandler = interactionHandler
    }
    
    let viewModelBuilder: ViewModelBuilderT
    let interactionHandler: InteractionHandlerT?
    lazy var sizingCell: CallMessageCollectionViewCell = {
        var cell: CallMessageCollectionViewCell?
        if Thread.isMainThread {
            cell = CallMessageCollectionViewCell.sizingCell()
        } else {
            DispatchQueue.main.sync(execute: {
                cell = CallMessageCollectionViewCell.sizingCell()
            })
        }
        
        return cell!
    }()
    
    lazy var callCellStyle: CallBubbleViewStyle = CallBubbleViewStyle()
    lazy var baseCellStyle: BaseMessageCollectionViewCellStyleProtocol = BaseMessageCollectionViewCellDefaultStyle()
    
    func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return self.viewModelBuilder.canCreateViewModel(fromModel: chatItem)
    }
    
    func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        return CallMessagePresenter<ViewModelBuilderT, InteractionHandlerT>(messageModel: chatItem as! ModelT,
                                                                             viewModelBuilder: self.viewModelBuilder,
                                                                             interactionHandler: self.interactionHandler,
                                                                             sizingCell: sizingCell,
                                                                             baseCellStyle: baseCellStyle,
                                                                             callCellStyle: callCellStyle,
                                                                             layoutCache: layoutCache)
    }
    
    var presenterType: ChatItemPresenterProtocol.Type {
        return CallMessagePresenter<ViewModelBuilderT, InteractionHandlerT>.self
    }
}
