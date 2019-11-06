//
//  AudioMessageModel.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

let audioExtension = "ogg"
private let audioUTI = "org.xiph.oga"

class AudioMessageModel: AudioItem, FileStatusType {
    var duration: Int
    
    var seconds: Int
    
    var length: String
    
    var contentWidth: CGFloat
    
    var name: String
    
    var fileSize: String
    
    var path: String? {
        return messageFile.filePath()
    }
    
    var progress: BehaviorRelay<Float>
    
    var progressObject: ChatProgressBridge
    
    var status: BehaviorRelay<FileTransferProgress>
    
    private var messageFile: OCTMessageFile
    
    init(messageFile: OCTMessageFile) {
        self.messageFile = messageFile
        
        let fullName = messageFile.fileName
        duration = AudioMessageModel.durationFromFileName(fullName)
        seconds = AudioMessageModel.secondsFromDuration(duration)
        length = "\(seconds)''"
        contentWidth = WaveformView.estimatedWidth(forDurationInSeconds: Int(seconds))
        
        name = messageFile.fileName ?? ""
        fileSize = ByteCountFormatter.string(fromByteCount: messageFile.fileSize, countStyle: ByteCountFormatter.CountStyle.file)
        
        status = BehaviorRelay<FileTransferProgress>(value: messageFile.fileType.toFileStatus(isOffline: messageFile.isOffline, expired: messageFile.expired))
        progress = BehaviorRelay(value: 0)
        
        progressObject = ChatProgressBridge()
        progressObject.updateProgress = { [weak self] (progress: Float, message: OCTMessageAbstract) -> Void in
            self?.progress.accept(progress)
        }
    }
    
    public static func isAudioFile(fileName: String?) -> Bool {
        return (fileName as NSString?)?.pathExtension == audioExtension
    }
    
    private static func durationFromFileName(_ fileName: String?) -> Int {
        guard let name = fileName else {
            return 0
        }
        
        var duration: Int = 0
        let fileName = (name as NSString).deletingPathExtension
        if fileName.contains("_"), let durationString = fileName.components(separatedBy: "_").last {
            duration = Int(durationString) ?? 0
        } else if fileName.contains(" "), let durationString = fileName.components(separatedBy: " ").first {
            duration = Int(durationString) ?? 0
        } else {
            duration = Int(fileName) ?? 0
        }
        return duration
    }
    
    private static func secondsFromDuration(_ duration: Int) -> Int {
        return Int(round(Double(duration) / millisecondsPerSecond))
    }
}
