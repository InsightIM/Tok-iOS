//
//  VideoMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import RxSwift
import RxCocoa

class VideoMessageViewModel: DecoratedMessageViewModelProtocol, FileTransferViewModelPorotocol {
    private let disposeBag = DisposeBag()
    
    let messageModel: MessageModelProtocol
    let messageViewModel: MessageViewModelProtocol
    
    let transferStatus: TransferStatus
    var updateProgress: ((Double) -> Void)?
    var transferDirection: ChattoAdditions.Observable<TransferDirection> = Observable(.download)
    let cellAccessibilityIdentifier = "chatto.message.video.cell"
    let bubbleAccessibilityIdentifier = "chatto.message.video.bubble"
    
    var image: ChattoAdditions.Observable<UIImage?>
    let imageSize: CGSize
    let fileSize: String
    let duration: String?
    let isIncoming: Bool
    let renewable: Bool
    
    init(messageModel: VideoMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.messageModel = messageModel
        self.messageViewModel = messageViewModel
        self.image = Observable(messageModel.image)
        self.imageSize = messageModel.imageSize
        self.fileSize = messageModel.fileSize
        self.duration = messageModel.duration
        self.isIncoming = messageModel.messageModel.isIncoming
        self.renewable = messageModel.renewable
        transferStatus = messageModel.transferStatus
        
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

class VideoMessageViewModelBuilder: ViewModelBuilderProtocol {
    typealias ModelT = VideoMessageModel
    typealias ViewModelT = VideoMessageViewModel
    
    let messageViewModelBuilder: MessageViewModelDefaultBuilder
    init(_ messageViewModelBuilder: MessageViewModelDefaultBuilder) {
        self.messageViewModelBuilder = messageViewModelBuilder
    }
    
    func createViewModel(_ model: VideoMessageModel) -> VideoMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let fileMessageViewModel = VideoMessageViewModel(messageModel: model, messageViewModel: messageViewModel)
        return fileMessageViewModel
    }
    
    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is VideoMessageModel
    }
}
