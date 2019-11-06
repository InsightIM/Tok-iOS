//
//  AudioMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import ChattoAdditions
import RxSwift
import RxCocoa

class AudioMessageModel: DecoratedMessageModelProtocol, TransferProgressHanlder {
    let disposeBag = DisposeBag()
    let transferStatus: TransferStatus
    let progress = BehaviorRelay(value: 0.0)
    
    let messageModel: MessageModelProtocol
    
    let duration: UInt
    let filePath: String?
    let renewable: Bool
    let unread: Bool
    init(messageModel: ChattoAdditionsMessageModel, duration: UInt, filePath: String?, transferStatus: TransferStatus, renewable: Bool, unread: Bool) {
        self.messageModel = messageModel
        self.duration = duration
        self.filePath = filePath
        self.transferStatus = transferStatus
        self.renewable = renewable
        self.unread = unread
    }
}
