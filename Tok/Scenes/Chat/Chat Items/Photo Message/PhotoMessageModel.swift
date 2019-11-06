//
//  PhotoMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions
import RxSwift
import RxCocoa

class PhotoMessageModel: DecoratedMessageModelProtocol, TransferProgressHanlder {
    let disposeBag = DisposeBag()
    let transferStatus: TransferStatus
    let progress = BehaviorRelay(value: 0.0)
    
    let messageModel: MessageModelProtocol
    
    let image: UIImage?
    let imageSize: CGSize
    let fileSize: String
    let filePath: String?
    let renewable: Bool
    init(messageModel: ChattoAdditionsMessageModel, image: UIImage?, imageSize: CGSize, fileSize: String, filePath: String?, transferStatus: TransferStatus, renewable: Bool) {
        self.messageModel = messageModel

        self.image = image
        self.imageSize = imageSize
        self.fileSize = fileSize
        self.filePath = filePath
        self.transferStatus = transferStatus
        self.renewable = renewable
    }
}
