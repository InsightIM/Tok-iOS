//
//  PhotoMessageHandler.swift
//  Tok
//
//  Created by Bryce on 2019/6/30.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions

protocol MediaMessageHandlerDelegate: class {
    func mediaMessageHandler(sourceViewForMessageBy id: String) -> UIImageView?
}

class MediaMessageHandler: BaseMessageHandler {
    weak var delegate: MediaMessageHandlerDelegate?
    private var imageBrowserDataSource: ImageBrowserDataSource?
    
    override func userDidTapOnBubble(viewModel: MessageViewModelProtocol) {
        guard viewModel is PhotoMessageViewModel || viewModel is VideoMessageViewModel else {
            return
        }
        guard !viewModel.isIncoming || (viewModel.isIncoming && viewModel.status == .success) else {
            return
        }
        let database = dataSource.messageService.database
        guard let message = database.findMessage(by: viewModel.messageModel.uid) else {
            return
        }
        
        let sourceView = delegate?.mediaMessageHandler(sourceViewForMessageBy: viewModel.messageModel.uid)
        let messages = database.findAllMediaMessages(chatId: dataSource.chat.uniqueIdentifier)
        let currentIndex = UInt(messages.indexOfObject(message))
        
        imageBrowserDataSource = ImageBrowserDataSource(sourceView: sourceView, dataSource: messages, currentIndex: currentIndex)
        let browser = YBImageBrowser()
        browser.dataSource = imageBrowserDataSource
        browser.currentIndex = currentIndex
        browser.show()
    }
}

class ImageBrowserDataSource: NSObject, YBImageBrowserDataSource {
    let sourceView: UIImageView?
    let dataSource: Results<OCTMessageAbstract>
    let currentIndex: UInt
    init(sourceView: UIImageView?, dataSource: Results<OCTMessageAbstract>, currentIndex: UInt) {
        self.sourceView = sourceView
        self.dataSource = dataSource
        self.currentIndex = currentIndex
        
        super.init()
    }
    
    func yb_numberOfCell(for imageBrowserView: YBImageBrowserView) -> UInt {
        return UInt(dataSource.count)
    }
    
    func yb_imageBrowserView(_ imageBrowserView: YBImageBrowserView, dataForCellAt index: UInt) -> YBImageBrowserCellDataProtocol {
        let sourceObject = currentIndex == index ? sourceView : nil
        let message = dataSource[index]
        guard let messageFile = message.messageFile, let filePath = messageFile.filePath() else {
            return YBImageBrowseCellData()
        }
        
        if messageFile.isImage() {
            let cell = YBImageBrowseCellData()
            cell.imageBlock = { YYImage(contentsOfFile: filePath) }
            cell.sourceObject = sourceObject
            return cell
        }
        
        if messageFile.isVideo() {
            let cell = YBVideoBrowseCellData()
            cell.url = URL(fileURLWithPath: filePath)
            cell.sourceObject = sourceObject
            return cell
        }
        return YBImageBrowseCellData()
    }
}
