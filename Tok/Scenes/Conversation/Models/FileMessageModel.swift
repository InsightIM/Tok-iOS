//
//  FileMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class FileMessageModel: FileItem, FileStatusType {
    var name: String
    
    var fileSize: String
    
    var path: String?
    
    var progress: BehaviorRelay<Float>
    
    var progressObject: ChatProgressBridge
    
    var status: BehaviorRelay<FileTransferProgress>
    
    init(messageFile: OCTMessageFile) {
        name = messageFile.fileName ?? ""
        fileSize = ByteCountFormatter.string(fromByteCount: messageFile.fileSize, countStyle: ByteCountFormatter.CountStyle.file)
        path = messageFile.filePath()
        
        status = BehaviorRelay<FileTransferProgress>(value: messageFile.fileType.toFileStatus(isOffline: messageFile.isOffline, expired: messageFile.expired))
        progress = BehaviorRelay(value: 0)
        
        progressObject = ChatProgressBridge()
        progressObject.updateProgress = { [weak self] (progress: Float, message: OCTMessageAbstract) -> Void in
            self?.progress.accept(progress)
        }
    }
}
