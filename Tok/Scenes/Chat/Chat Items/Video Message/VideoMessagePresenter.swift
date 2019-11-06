//
//  VideoMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

class VideoMessagePresenter<ViewModelBuilderT, InteractionHandlerT>: BaseMessagePresenter<VideoBubbleView, ViewModelBuilderT, InteractionHandlerT> where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == VideoMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & FileOperationHandlerProtocol & UIMenuItemHandlerProtocol,
    InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    let bubbleCellStyle: VideoBubbleViewStyle
    private var menuPresenter: ChatItemMenuPresenterProtocol?
    init (
        messageModel: ModelT,
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: VideoMessageCollectionViewCell,
        baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
        bubbleCellStyle: VideoBubbleViewStyle) {
        self.bubbleCellStyle = bubbleCellStyle

        super.init(
            messageModel: messageModel,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            cellStyle: baseCellStyle
        )
    }
    
    final override class func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(VideoMessageCollectionViewCell.self, forCellWithReuseIdentifier: "video-message")
    }
    
    final override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "video-message", for: indexPath)
    }
    
    override func createViewModel() -> VideoMessageViewModel {
        let viewModel = self.viewModelBuilder.createViewModel(self.messageModel)
        self.menuPresenter = MeidaMessageMenuItemPresenter(viewModel: viewModel, menuHandler: interactionHandler)
        let updateClosure = { [weak self] (old: Any, new: Any) -> Void in
            self?.updateCurrentCell()
        }
        viewModel.avatarImage.observe(self, closure: updateClosure)
        return viewModel
    }
    
    override func configureCell(_ cell: BaseMessageCollectionViewCell<VideoBubbleView>, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? VideoMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }
        
        super.configureCell(cell, decorationAttributes: decorationAttributes, animated: animated) { () -> Void in
            cell.viewModel = self.messageViewModel
            cell.style = self.bubbleCellStyle
            cell.bubbleView.didTapOperationButton = { [weak self] in
                self?.onCellOperationButtonTapped()
            }
            additionalConfiguration?()
        }
    }
    
    var videoCell: VideoMessageCollectionViewCell? {
        if let cell = self.cell {
            if let audioCell = cell as? VideoMessageCollectionViewCell {
                return audioCell
            } else {
                assert(false, "Invalid cell was given to presenter!")
            }
        }
        return nil
    }
    
    func updateCurrentCell() {
        if let cell = self.videoCell, let decorationAttributes = self.decorationAttributes {
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

class VideoMessagePresenterBuilder<ViewModelBuilderT, InteractionHandlerT>: ChatItemPresenterBuilderProtocol where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == VideoMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & FileOperationHandlerProtocol & UIMenuItemHandlerProtocol,
    InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    
    typealias ModelT = ViewModelBuilderT.ModelT
    typealias ViewModelT = ViewModelBuilderT.ViewModelT
    
    init(
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?) {
        self.viewModelBuilder = viewModelBuilder
        self.interactionHandler = interactionHandler
    }
    
    let viewModelBuilder: ViewModelBuilderT
    let interactionHandler: InteractionHandlerT?
    lazy var sizingCell: VideoMessageCollectionViewCell = {
        var cell: VideoMessageCollectionViewCell?
        if Thread.isMainThread {
            cell = VideoMessageCollectionViewCell.sizingCell()
        } else {
            DispatchQueue.main.sync(execute: {
                cell = VideoMessageCollectionViewCell.sizingCell()
            })
        }
        
        return cell!
    }()
    
    lazy var bubbleCellStyle: VideoBubbleViewStyle = VideoBubbleViewStyle()
    lazy var baseCellStyle: BaseMessageCollectionViewCellStyleProtocol = BaseMessageCollectionViewCellDefaultStyle()
    
    func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return self.viewModelBuilder.canCreateViewModel(fromModel: chatItem)
    }
    
    func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        return VideoMessagePresenter<ViewModelBuilderT, InteractionHandlerT>(messageModel: chatItem as! ModelT,
                                                                            viewModelBuilder: self.viewModelBuilder,
                                                                            interactionHandler: self.interactionHandler,
                                                                            sizingCell: sizingCell,
                                                                            baseCellStyle: baseCellStyle,
                                                                            bubbleCellStyle: bubbleCellStyle)
    }
    
    var presenterType: ChatItemPresenterProtocol.Type {
        return VideoMessagePresenter<ViewModelBuilderT, InteractionHandlerT>.self
    }
}
