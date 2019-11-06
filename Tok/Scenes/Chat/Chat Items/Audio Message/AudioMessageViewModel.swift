//
//  AudioMessageViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import RxSwift
import RxCocoa

class AudioMessageViewModel: DecoratedMessageViewModelProtocol, FileTransferViewModelPorotocol {
    private let disposeBag = DisposeBag()
    
    let messageModel: MessageModelProtocol
    let messageViewModel: MessageViewModelProtocol
    
    let text: String
    let duration: UInt
    let isIncoming: Bool
    let renewable: Bool
    let filePath: String?
    var unread: ChattoAdditions.Observable<Bool>
    
    let transferStatus: TransferStatus
    var updateProgress: ((Double) -> Void)?
    let cellAccessibilityIdentifier = "chatto.message.audio.cell"
    let bubbleAccessibilityIdentifier = "chatto.message.audio.bubble"
    
    init(messageModel: AudioMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.messageModel = messageModel
        self.messageViewModel = messageViewModel
        
        let seconds = AudioMessageViewModel.secondsFromDuration(messageModel.duration)
        self.text = "\(seconds)''"
        self.duration = seconds
        self.filePath = messageModel.filePath
        self.isIncoming = messageModel.messageModel.isIncoming
        self.renewable = messageModel.renewable
        self.unread = Observable(messageModel.unread)
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
    
    private static func secondsFromDuration(_ duration: UInt) -> UInt {
        return UInt(round(Double(duration) / millisecondsPerSecond))
    }
}

class AudioMessageViewModelBuilder: ViewModelBuilderProtocol {
    typealias ModelT = AudioMessageModel
    typealias ViewModelT = AudioMessageViewModel
    
    let messageViewModelBuilder: MessageViewModelDefaultBuilder
    init(_ messageViewModelBuilder: MessageViewModelDefaultBuilder) {
        self.messageViewModelBuilder = messageViewModelBuilder
    }
    
    func createViewModel(_ model: AudioMessageModel) -> AudioMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)
        let audioMessageViewModel = AudioMessageViewModel(messageModel: model, messageViewModel: messageViewModel)
        return audioMessageViewModel
    }
    
    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is AudioMessageModel
    }
}
