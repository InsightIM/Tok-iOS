//
//  FileMessageService.swift
//  Tok
//
//  Created by Bryce on 2019/7/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class FileQueue {
    private let queue = OperationQueue()
    
    init(maxConcurrentOperationCount: Int = 1) {
        queue.maxConcurrentOperationCount = maxConcurrentOperationCount
    }
    
    func add(_ operation: BaseFileOperation) {
        guard !isExist(operationId: operation.getOperationId()) else {
            return
        }
        queue.addOperation(operation)
        if queue.isSuspended {
            resume()
        }
    }
    
    func cancelAllOperations() {
        queue.cancelAllOperations()
    }
    
    func suspend() {
        queue.isSuspended = true
    }
    
    func resume() {
        queue.isSuspended = false
    }
    
    func isExist(operationId: String) -> Bool {
        guard queue.operations.count > 0 else {
            return false
        }
        return queue.operations.contains(where: { (operation) -> Bool in
            (operation as? BaseFileOperation)?.getOperationId() == operationId && !operation.isCancelled
        })
    }
    
    func find(by operationId: String) -> BaseFileOperation? {
        return queue.operations
            .first { ($0 as? BaseFileOperation)?.getOperationId() == operationId }
            as? BaseFileOperation
    }
    
    func find(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber) -> BaseFileOperation? {
        return queue.operations
            .first { ($0 as? BaseFileOperation)?.fileNumber == fileNumber && ($0 as? BaseFileOperation)?.friendNumber == friendNumber }
            as? BaseFileOperation
    }
}
