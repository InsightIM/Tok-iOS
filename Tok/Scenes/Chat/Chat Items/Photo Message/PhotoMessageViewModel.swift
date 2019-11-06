//
//  PhotoMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import RxSwift
import RxCocoa

public protocol FileTransferViewModelPorotocol {
    var updateProgress: ((Double) -> Void)? { get set }
    var transferStatus: TransferStatus { get }
}

class PhotoMessageViewModel: DecoratedMessageViewModelProtocol, FileTransferViewModelPorotocol {
    private let disposeBag = DisposeBag()
    
    let messageModel: MessageModelProtocol
    let messageViewModel: MessageViewModelProtocol
    
    var updateProgress: ((Double) -> Void)?
    var transferStatus: TransferStatus
    var transferDirection: ChattoAdditions.Observable<TransferDirection> = Observable(.download)
    let cellAccessibilityIdentifier = "tok.message.photo.cell"
    let bubbleAccessibilityIdentifier = "tok.message.photo.bubble"
    
    var image: ChattoAdditions.Observable<UIImage?>
    let imageSize: CGSize
    let fileSize: String
    let isIncoming: Bool
    let renewable: Bool
    
    init(messageModel: PhotoMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.messageModel = messageModel
        self.messageViewModel = messageViewModel
        self.image = Observable(messageModel.image)
        self.imageSize = messageModel.imageSize
        self.fileSize = messageModel.fileSize
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
