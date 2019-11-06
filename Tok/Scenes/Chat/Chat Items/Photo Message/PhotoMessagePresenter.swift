//
//  PhotoMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/6/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import Chatto
import ChattoAdditions

class PhotoMessagePresenter<ViewModelBuilderT, InteractionHandlerT>: BaseMessagePresenter<PhotoBubbleView, ViewModelBuilderT, InteractionHandlerT> where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == PhotoMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & FileOperationHandlerProtocol & UIMenuItemHandlerProtocol,
InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    public typealias ModelT = ViewModelBuilderT.ModelT
    public typealias ViewModelT = ViewModelBuilderT.ViewModelT
    
    public let photoCellStyle: PhotoMessageStyle
    private var menuPresenter: ChatItemMenuPresenterProtocol?
    public init (
        messageModel: ModelT,
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: PhotoMessageCollectionViewCell,
        baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
        photoCellStyle: PhotoMessageStyle) {
        self.photoCellStyle = photoCellStyle
        super.init(
            messageModel: messageModel,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            cellStyle: baseCellStyle
        )
    }
    
    public final override class func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(PhotoMessageCollectionViewCell.self, forCellWithReuseIdentifier: "photo-message")
    }
    
    public final override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "photo-message", for: indexPath)
    }
    
    open override func createViewModel() -> ViewModelBuilderT.ViewModelT {
        let viewModel = self.viewModelBuilder.createViewModel(self.messageModel)
        self.menuPresenter = MeidaMessageMenuItemPresenter(viewModel: viewModel, menuHandler: interactionHandler)

        let updateClosure = { [weak self] (old: Any, new: Any) -> Void in
            self?.updateCurrentCell()
        }
        viewModel.avatarImage.observe(self, closure: updateClosure)
        viewModel.image.observe(self, closure: updateClosure)
        return viewModel
    }
    
    public var photoCell: PhotoMessageCollectionViewCell? {
        if let cell = self.cell {
            if let photoCell = cell as? PhotoMessageCollectionViewCell {
                return photoCell
            } else {
                assert(false, "Invalid cell was given to presenter!")
            }
        }
        return nil
    }
    
    open override func configureCell(_ cell: BaseMessageCollectionViewCell<PhotoBubbleView>, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? PhotoMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }
        
        super.configureCell(cell, decorationAttributes: decorationAttributes, animated: animated) { () -> Void in
            cell.photoMessageViewModel = self.messageViewModel
            cell.photoMessageStyle = self.photoCellStyle
            cell.bubbleView.didTapOperationButton = { [weak self] in
                self?.onCellOperationButtonTapped()
            }
            additionalConfiguration?()
        }
    }
    
    public func updateCurrentCell() {
        if let cell = self.photoCell, let decorationAttributes = self.decorationAttributes {
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
    
    func onCellOperationButtonTapped() {
        interactionHandler?.userDidTapOnOperationButton(viewModel: messageViewModel)
    }
}

class PhotoMessagePresenterBuilder<ViewModelBuilderT, InteractionHandlerT>: ChatItemPresenterBuilderProtocol where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == PhotoMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & FileOperationHandlerProtocol & UIMenuItemHandlerProtocol,
InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    public typealias ModelT = ViewModelBuilderT.ModelT
    public typealias ViewModelT = ViewModelBuilderT.ViewModelT
    
    public init(
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?) {
        self.viewModelBuilder = viewModelBuilder
        self.interactionHandler = interactionHandler
    }
    
    public let viewModelBuilder: ViewModelBuilderT
    public let interactionHandler: InteractionHandlerT?
    public let sizingCell: PhotoMessageCollectionViewCell = PhotoMessageCollectionViewCell.sizingCell()
    public lazy var photoCellStyle: PhotoMessageStyle = PhotoMessageStyle()
    public lazy var baseCellStyle: BaseMessageCollectionViewCellStyleProtocol = BaseMessageCollectionViewCellDefaultStyle()
    
    open func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return self.viewModelBuilder.canCreateViewModel(fromModel: chatItem)
    }
    
    open func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        assert(self.canHandleChatItem(chatItem))
        return PhotoMessagePresenter<ViewModelBuilderT, InteractionHandlerT>(
            messageModel: chatItem as! ModelT,
            viewModelBuilder: self.viewModelBuilder,
            interactionHandler: self.interactionHandler,
            sizingCell: sizingCell,
            baseCellStyle: self.baseCellStyle,
            photoCellStyle: self.photoCellStyle
        )
    }
    
    open var presenterType: ChatItemPresenterProtocol.Type {
        return PhotoMessagePresenter<ViewModelBuilderT, InteractionHandlerT>.self
    }
}
