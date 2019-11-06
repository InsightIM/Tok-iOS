//
//  BaseOperation.swift
//  Tok
//
//  Created by Bryce on 2019/7/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

struct EtaObject {
    let deltaTime: Double
    let deltaBytes: OCTToxFileSize
}

class BaseFileOperation: AsyncOperation {
    let messageId: OCTToxMessageId
    let tox: OCTTox
    let database: Database
    
    let kind: OCTToxFileKind
    let friendNumber: OCTToxFriendNumber
    var fileNumber: OCTToxFileNumber
    let fileSize: OCTToxFileSize
    var progress: ((BaseFileOperation, Double) -> Void)?
    var completionCallback: ((BaseFileOperation, Bool) -> Void)?
    
    func getOperationId() -> String {
        fatalError("Subclasses must implement `getOperationId`.")
    }
    
    static func operationId(messageId: OCTToxMessageId) -> String {
         return "\(messageId)"
    }
    
    init(messageId: OCTToxMessageId, tox: OCTTox, database: Database, kind: OCTToxFileKind, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber, fileSize: OCTToxFileSize, progress: ((BaseFileOperation, Double) -> Void)? = nil, completionCallback: ((BaseFileOperation, Bool) -> Void)? = nil) {
        self.messageId = messageId
        self.tox = tox
        self.database = database
        self.kind = kind
        self.friendNumber = friendNumber
        self.fileNumber = fileNumber
        self.fileSize = fileSize
        self.progress = progress
        self.completionCallback = completionCallback
    }
    
    private(set) var bytesDone: OCTToxFileSize = 0
//    private(set) var currentProgress: Double = 0
    private var bytesPerSecond: OCTToxFileSize = 0
    private(set) var eta: Double = 0
    
    private var lastUpdateProgressTime: CFTimeInterval = 0
    private var lastUpdateBytesDone: OCTToxFileSize = 0
    private var lastUpdateEtaProgressTime: CFTimeInterval = 0
    private var lastUpdateEtaBytesDone: OCTToxFileSize = 0
    private var last10EtaObjects: [EtaObject] = []
    
    private struct Constants {
        static let kMinUpdateProgressInterval: CFTimeInterval = 0.1
        static let kMinUpdateEtaInterval: CFTimeInterval = 1.0
        static let kTimeoutInterval: CFTimeInterval = 20
    }
    
    // MARK: - Timeout Timer
    
    private var timer: Timer?
    private func runTimer() {
        performAsynchronouslyOnMainThread {
            self.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] timer in
                guard let self = self else {
                    print("Operation is nil, Timer invalidate")
                    timer.invalidate()
                    return
                }
                
                let deltaTime = CACurrentMediaTime() - self.lastUpdateProgressTime
                if deltaTime > Constants.kTimeoutInterval {
                    self.completion(success: false)
                }
            })
            self.timer?.fire()
        }
    }
    
    private func tearDown() {
        performAsynchronouslyOnMainThread {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    // Mark: - Override
    
    override func main() {
        guard execute() else {
            completion(success: false)
            return
        }
        
        lastUpdateProgressTime = CACurrentMediaTime()
        lastUpdateBytesDone = 0
        lastUpdateEtaProgressTime = CACurrentMediaTime()
        lastUpdateEtaBytesDone = 0
        last10EtaObjects = []
        
        runTimer()
    }
    
    // MARK: - Custom
    
    open func execute() -> Bool {
        fatalError("Subclasses must implement `execute`.")
    }
    
    override func cancel() {
        try? tox.fileSendControl(forFileNumber: fileNumber, friendNumber: friendNumber, control: .cancel)
        super.cancel()
    }
    
    open func completion(success: Bool) {
        if !success {
            try? tox.fileSendControl(forFileNumber: fileNumber, friendNumber: friendNumber, control: .cancel)
        }
        
        self.finish()
        self.tearDown()
        self.completionCallback?(self, success)
        
        guard let message = self.database.findFileMessage(by: self.messageId),
            let messageFile = message.messageFile else {
                return
        }
        
        if success {
            guard messageFile.fileType != .ready else { return }
            self.database.update(object: messageFile) { messageFile in
                messageFile.fileType = .ready
            }
        } else {
            self.database.update(object: messageFile) { messageFile in
                messageFile.fileType = .canceled
            }
        }
    }
    
    // MARK: - Private
    
    func update(bytesDone: OCTToxFileSize) {
        self.bytesDone = bytesDone
        
        updateProgressIfNeeded(bytesDone: bytesDone)
        updateEtaIfNeeded(bytesDone: bytesDone)
    }
    
    func updateProgressIfNeeded(bytesDone: OCTToxFileSize) {
        let time = CACurrentMediaTime()
        let deltaTime = time - lastUpdateProgressTime
        guard deltaTime > Constants.kMinUpdateProgressInterval else {
            return
        }
        
        lastUpdateProgressTime = time
        lastUpdateBytesDone = bytesDone
        
        let currentProgress = Double(bytesDone) / Double(fileSize)
        
        // update progress
        self.progress?(self, currentProgress)
    }
    
    func updateEtaIfNeeded(bytesDone: OCTToxFileSize) {
        let time = CACurrentMediaTime()
        let deltaTime = time - lastUpdateProgressTime
        
        guard deltaTime > Constants.kMinUpdateEtaInterval else {
            return
        }
        
        let deltaBytes = bytesDone - lastUpdateEtaBytesDone
        let bytesLeft = fileSize - bytesDone
        
        let etaObject = EtaObject(deltaTime: deltaTime, deltaBytes: deltaBytes)
        last10EtaObjects.append(etaObject)
        if last10EtaObjects.count > 10 {
            last10EtaObjects.remove(at: 0)
        }
        
        var totalDeltaTime: Double = 0.0
        var totalDeltaBytes: OCTToxFileSize = 0
        
        last10EtaObjects.forEach { object in
            totalDeltaTime += object.deltaTime
            totalDeltaBytes += object.deltaBytes
        }
        
        bytesPerSecond = totalDeltaBytes / Int64(totalDeltaTime)
        
        if totalDeltaBytes > 0 {
            self.eta = totalDeltaTime * Double(bytesLeft) / Double(totalDeltaBytes)
        }
        
        // update eta
    }
}
