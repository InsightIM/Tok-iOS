//
//  FileMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/6/6.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import RxSwift
import RxCocoa

class FileMessageModel: DecoratedMessageModelProtocol, TransferProgressHanlder {
    let disposeBag = DisposeBag()
    let transferStatus: TransferStatus
    let progress = BehaviorRelay(value: 0.0)
    
    var messageModel: MessageModelProtocol
    
    let fileName: String?
    let fileSize: String
    let filePath: String?
    let renewable: Bool
    init(messageModel: ChattoAdditionsMessageModel, fileName: String?, fileSize: String, filePath: String?, transferStatus: TransferStatus, renewable: Bool) {
        self.messageModel = messageModel
        self.fileName = fileName
        self.fileSize = fileSize
        self.filePath = filePath
        self.transferStatus = transferStatus
        self.renewable = renewable
    }
}
