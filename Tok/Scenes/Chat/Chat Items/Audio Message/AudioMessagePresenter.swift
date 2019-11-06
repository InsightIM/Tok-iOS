//
//  AudioMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/6/4.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

class AudioMessagePresenter<ViewModelBuilderT, InteractionHandlerT>: BaseMessagePresenter<AudioBubbleView, ViewModelBuilderT, InteractionHandlerT> where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == AudioMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & FileOperationHandlerProtocol & UIMenuItemHandlerProtocol,
    InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    private var menuPresenter: ChatItemMenuPresenterProtocol?
    let layoutCache: NSCache<AnyObject, AnyObject>
    let audioCellStyle: AudioBubbleViewStyle
    init (
        messageModel: ModelT,
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: AudioMessageCollectionViewCell,
        baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
        audioCellStyle: AudioBubbleViewStyle,
        layoutCache: NSCache<AnyObject, AnyObject>) {
        self.layoutCache = layoutCache
        self.audioCellStyle = audioCellStyle
        super.init(
            messageModel: messageModel,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            cellStyle: baseCellStyle
        )
    }
    
    final override class func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(AudioMessageCollectionViewCell.self, forCellWithReuseIdentifier: "audio-message")
    }
    
    final override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "audio-message", for: indexPath)
    }
    
    override func createViewModel() -> AudioMessageViewModel {
        let viewModel = self.viewModelBuilder.createViewModel(self.messageModel)
        self.menuPresenter = AudioMessageMenuItemPresenter(viewModel: viewModel, menuHandler: interactionHandler)
        let updateClosure = { [weak self] (old: Any, new: Any) -> Void in
            self?.updateCurrentCell()
        }
        viewModel.avatarImage.observe(self, closure: updateClosure)
        viewModel.unread.observe(self) { [weak self] (_, unread) in
            guard let self = self else { return }
            if let cell = self.audioCell, unread == false {
                cell.bubbleView.unreadImageView.image = nil
            }
        }
        return viewModel
    }
    
    override func configureCell(_ cell: BaseMessageCollectionViewCell<AudioBubbleView>, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? AudioMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }
        
        super.configureCell(cell, decorationAttributes: decorationAttributes, animated: animated) { () -> Void in
            cell.layoutCache = self.layoutCache
            cell.viewModel = self.messageViewModel
            cell.style = self.audioCellStyle
            cell.bubbleView.didTapOperationButton = { [weak self] in
                self?.onCellOperationButtonTapped()
            }
            additionalConfiguration?()
        }
    }
    
    var audioCell: AudioMessageCollectionViewCell? {
        if let cell = self.cell {
            if let audioCell = cell as? AudioMessageCollectionViewCell {
                return audioCell
            } else {
                assert(false, "Invalid cell was given to presenter!")
            }
        }
        return nil
    }
    
    func updateCurrentCell() {
        if let cell = self.audioCell, let decorationAttributes = self.decorationAttributes {
            self.configureCell(cell, decorationAttributes: decorationAttributes, animated: self.itemVisibility != .appearing, additionalConfiguration: nil)
        }
    }
    
    func onCellOperationButtonTapped() {
        interactionHandler?.userDidTapOnOperationButton(viewModel: messageViewModel)
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

class AudioMessagePresenterBuilder<ViewModelBuilderT, InteractionHandlerT>: ChatItemPresenterBuilderProtocol where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT == AudioMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & FileOperationHandlerProtocol & UIMenuItemHandlerProtocol,
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
    lazy var sizingCell: AudioMessageCollectionViewCell = {
        var cell: AudioMessageCollectionViewCell?
        if Thread.isMainThread {
            cell = AudioMessageCollectionViewCell.sizingCell()
        } else {
            DispatchQueue.main.sync(execute: {
                cell = AudioMessageCollectionViewCell.sizingCell()
            })
        }
        
        return cell!
    }()
    
    lazy var audioCellStyle: AudioBubbleViewStyle = AudioBubbleViewStyle()
    lazy var baseCellStyle: BaseMessageCollectionViewCellStyleProtocol = BaseMessageCollectionViewCellDefaultStyle()
    
    func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return self.viewModelBuilder.canCreateViewModel(fromModel: chatItem)
    }
    
    func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        return AudioMessagePresenter<ViewModelBuilderT, InteractionHandlerT>(messageModel: chatItem as! ModelT,
                                                                             viewModelBuilder: self.viewModelBuilder,
                                                                             interactionHandler: self.interactionHandler,
                                                                             sizingCell: sizingCell,
                                                                             baseCellStyle: baseCellStyle,
                                                                             audioCellStyle: audioCellStyle,
                                                                             layoutCache: layoutCache)
    }
    
    var presenterType: ChatItemPresenterProtocol.Type {
        return AudioMessagePresenter<ViewModelBuilderT, InteractionHandlerT>.self
    }
}
