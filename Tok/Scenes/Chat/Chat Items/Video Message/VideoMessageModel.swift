//
//  VideoMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/6/7.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import RxSwift
import RxCocoa

class VideoMessageModel: DecoratedMessageModelProtocol, TransferProgressHanlder {
    let disposeBag = DisposeBag()
    let transferStatus: TransferStatus
    let progress = BehaviorRelay(value: 0.0)
    
    let messageModel: MessageModelProtocol
    
    let image: UIImage?
    let imageSize: CGSize
    let fileSize: String
    let filePath: String?
    let duration: String?
    let renewable: Bool
    init(messageModel: ChattoAdditionsMessageModel, image: UIImage?, imageSize: CGSize, fileSize: String, filePath: String?, duration: String?, transferStatus: TransferStatus, renewable: Bool) {
        self.messageModel = messageModel
        
        self.image = image
        self.imageSize = imageSize
        self.fileSize = fileSize
        self.filePath = filePath
        self.duration = duration
        self.transferStatus = transferStatus
        self.renewable = renewable
    }
}
