//
//  FileMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/6/6.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import RxSwift
import RxCocoa

class FileMessageViewModel: DecoratedMessageViewModelProtocol, FileTransferViewModelPorotocol {
    private let disposeBag = DisposeBag()
    
    let messageModel: MessageModelProtocol
    let messageViewModel: MessageViewModelProtocol
    
    var updateProgress: ((Double) -> Void)?
    var transferStatus: TransferStatus
    var transferDirection: ChattoAdditions.Observable<TransferDirection> = Observable(.download)
    let cellAccessibilityIdentifier = "chatto.message.file.cell"
    let bubbleAccessibilityIdentifier = "chatto.message.file.bubble"
    
    let fileName: String
    let fileSize: String
    let fileExtension: String
    let isIncoming: Bool
    let renewable: Bool
    
    init(messageModel: FileMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.messageModel = messageModel
        self.messageViewModel = messageViewModel
        self.fileName = messageModel.fileName ?? "File"
        self.fileSize = messageModel.fileSize
        self.isIncoming = messageModel.messageModel.isIncoming
        self.renewable = messageModel.renewable
        transferStatus = messageModel.transferStatus
        
        if let exten = (messageModel.fileName as NSString?)?.pathExtension.uppercased(), exten.count < 5, exten.count > 0 {
            self.fileExtension = exten
        } else {
            self.fileExtension = "FILE"
        }
        
        messageModel.progress
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] progress in
                self?.updateProgress?(progress)
            })
            .disposed(by: disposeBag)
    }
    
    func willBeShown() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
    
    func wasHidden() {
        // Need to declare empty. Otherwise subclass code won't execute (as of Xcode 7.2)
    }
}

class FileMessageViewModelBuilder: ViewModelBuilderProtocol {
    typealias ModelT = FileMessageModel
    typealias ViewModelT = FileMessageViewModel
    
    let messageViewModelBuilder: MessageViewModelDefaultBuilder
    init(_ messageViewModelBuilder: MessageViewModelDefaultBuilder) {
        self.messageViewModelBuilder = messageViewModelBuilder
    }
    
    func createViewModel(_ model: FileMessageModel) -> FileMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let fileMessageViewModel = FileMessageViewModel(messageModel: model, messageViewModel: messageViewModel)
        return fileMessageViewModel
    }
    
    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is FileMessageModel
    }
}
