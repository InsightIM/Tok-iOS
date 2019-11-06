//
//  TextMessagePresenter.swift
//  Tok
//
//  Created by Bryce on 2019/7/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

enum DetectedDataType: String, CaseIterable {
    case URL = "((?i)https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]"
    case tokId = "[A-Za-z0-9]{76}"
//    case mention = "@[^\\s:：,，@]+$?"
    case groupId = "#[A-Za-z0-9]{19}"
    case tokLink = "tok://\\S+"
//    case hashTag = "#.+?#"
//    case email = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]+"
}

protocol DetectedStringHandlerProtocol {
    func userDidTapOnDetectedString(text: String, detectedDataType: DetectedDataType, viewModel: MessageViewModelProtocol)
}

class TextMessagePresenter<ViewModelBuilderT, InteractionHandlerT>
    : BaseMessagePresenter<TextBubbleView, ViewModelBuilderT, InteractionHandlerT> where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT: TextMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & UIMenuItemHandlerProtocol & DetectedStringHandlerProtocol,
InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    public typealias ModelT = ViewModelBuilderT.ModelT
    public typealias ViewModelT = ViewModelBuilderT.ViewModelT
    
    public init (
        messageModel: ModelT,
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: TextMessageCollectionViewCell,
        baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
        textCellStyle: TextMessageStyle,
        layoutCache: NSCache<AnyObject, AnyObject>) {
        self.layoutCache = layoutCache
        self.textCellStyle = textCellStyle
        super.init(
            messageModel: messageModel,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            cellStyle: baseCellStyle
        )
    }
    
    private var menuPresenter: ChatItemMenuPresenterProtocol?
    let layoutCache: NSCache<AnyObject, AnyObject>
    let textCellStyle: TextMessageStyle
    
    public final override class func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(TextMessageCollectionViewCell.self, forCellWithReuseIdentifier: "text-message-incoming")
        collectionView.register(TextMessageCollectionViewCell.self, forCellWithReuseIdentifier: "text-message-outcoming")
    }
    
    public final override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = self.messageViewModel.isIncoming ? "text-message-incoming" : "text-message-outcoming"
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    
    open override func createViewModel() -> ViewModelBuilderT.ViewModelT {
        let viewModel = self.viewModelBuilder.createViewModel(self.messageModel)
        self.menuPresenter = MessageMenuItemPresenter(viewModel: viewModel, menuHandler: interactionHandler)
        
        let updateClosure = { [weak self] (old: Any, new: Any) -> Void in
            self?.updateCurrentCell()
        }
        viewModel.avatarImage.observe(self, closure: updateClosure)
        return viewModel
    }
    
    public var textCell: TextMessageCollectionViewCell? {
        if let cell = self.cell {
            if let textCell = cell as? TextMessageCollectionViewCell {
                return textCell
            } else {
                assert(false, "Invalid cell was given to presenter!")
            }
        }
        return nil
    }
    
    open override func configureCell(_ cell: BaseMessageCollectionViewCell<TextBubbleView>, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? TextMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }
        
        super.configureCell(cell, decorationAttributes: decorationAttributes, animated: animated) { () -> Void in
            cell.layoutCache = self.layoutCache
            cell.textMessageViewModel = self.messageViewModel
            cell.textMessageStyle = self.textCellStyle
            additionalConfiguration?()
        }
        
        cell.bubbleView.tapDetectedStringAction = { [weak self] (text, type) in
            guard let self = self else { return }
            self.interactionHandler?.userDidTapOnDetectedString(text: text, detectedDataType: type, viewModel: self.messageViewModel)
        }
    }
    
    public func updateCurrentCell() {
        if let cell = self.textCell, let decorationAttributes = self.decorationAttributes {
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

class TextMessagePresenterBuilder<ViewModelBuilderT, InteractionHandlerT>
    : ChatItemPresenterBuilderProtocol where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT: TextMessageViewModel,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol & UIMenuItemHandlerProtocol & DetectedStringHandlerProtocol,
InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    typealias ViewModelT = ViewModelBuilderT.ViewModelT
    typealias ModelT = ViewModelBuilderT.ModelT
    
    public init(
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT? = nil) {
        self.viewModelBuilder = viewModelBuilder
        self.interactionHandler = interactionHandler
    }
    
    let viewModelBuilder: ViewModelBuilderT
    let interactionHandler: InteractionHandlerT?
    let layoutCache = NSCache<AnyObject, AnyObject>()
    
    lazy var sizingCell: TextMessageCollectionViewCell = {
        var cell: TextMessageCollectionViewCell?
        if Thread.isMainThread {
            cell = TextMessageCollectionViewCell.sizingCell()
        } else {
            DispatchQueue.main.sync(execute: {
                cell =  TextMessageCollectionViewCell.sizingCell()
            })
        }
        
        return cell!
    }()
    
    public lazy var textCellStyle: TextMessageStyle = TextMessageStyle()
    public lazy var baseMessageStyle: BaseMessageCollectionViewCellStyleProtocol = BaseMessageCollectionViewCellDefaultStyle()
    
    open func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return self.viewModelBuilder.canCreateViewModel(fromModel: chatItem)
    }
    
    open func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        return self.createPresenter(withChatItem: chatItem,
                                    viewModelBuilder: self.viewModelBuilder,
                                    interactionHandler: self.interactionHandler,
                                    sizingCell: self.sizingCell,
                                    baseCellStyle: self.baseMessageStyle,
                                    textCellStyle: self.textCellStyle,
                                    layoutCache: self.layoutCache)
    }
    
    open func createPresenter(withChatItem chatItem: ChatItemProtocol,
                              viewModelBuilder: ViewModelBuilderT,
                              interactionHandler: InteractionHandlerT?,
                              sizingCell: TextMessageCollectionViewCell,
                              baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
                              textCellStyle: TextMessageStyle,
                              layoutCache: NSCache<AnyObject, AnyObject>) -> TextMessagePresenter<ViewModelBuilderT, InteractionHandlerT> {
        assert(self.canHandleChatItem(chatItem))
        return TextMessagePresenter<ViewModelBuilderT, InteractionHandlerT>(
            messageModel: chatItem as! ModelT,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            baseCellStyle: baseCellStyle,
            textCellStyle: textCellStyle,
            layoutCache: layoutCache
        )
    }
    
    open var presenterType: ChatItemPresenterProtocol.Type {
        return TextMessagePresenter<ViewModelBuilderT, InteractionHandlerT>.self
    }
}
