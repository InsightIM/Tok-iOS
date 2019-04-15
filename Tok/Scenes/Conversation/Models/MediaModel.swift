//
//  PhotoMediaItem.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import AVKit

class MediaModel: MediaItem, FileStatusType {
    
    var status: BehaviorRelay<FileTransferProgress>
    
    var progress: BehaviorRelay<Float>
    
    var progressObject: ChatProgressBridge
    
    var url: URL? {
        guard let filePath = messageFile.filePath() else {
            return nil
        }
        return URL(fileURLWithPath: filePath)
    }
    
    var image: UIImage?
    
    var size: CGSize {
        return image?.size ?? CGSize(width: 200, height: 200)
    }
    
    var placeholderImage: UIImage
    
    var isVideo: Bool
    
    var videoThumbnailPath: String? {
        return messageFile.videoThumbnailPath(thumbPath: thumbPath)
    }
    
    var thumbPath: String?
    
    var duration: String?
    
    var isOutgoing: Bool
    
    var messageFile: OCTMessageFile
    
    init(messageFile: OCTMessageFile, isOutgoing: Bool, thumbPath: String? = nil) {
        self.messageFile = messageFile
        self.isOutgoing = isOutgoing
        self.thumbPath = thumbPath
        self.duration = messageFile.duration
        
        placeholderImage = UIImage()
        status = BehaviorRelay<FileTransferProgress>(value: messageFile.fileType.toFileStatus())
        progress = BehaviorRelay(value: 0)
        
        isVideo = messageFile.isVideo()
        image = messageFile.getImage(thumbPath: thumbPath)
        
        progressObject = ChatProgressBridge()
        progressObject.updateProgress = { [weak self] (progress: Float, message: OCTMessageAbstract) -> Void in
            self?.progress.accept(progress)
        }
    }
    
    func fetchThumbnailAndDuration(complete: ((UIImage?, String?) -> Void)? = nil) {
        guard isVideo else {
            complete?(nil, nil)
            return
        }
        
        if let duration = duration, let image = image {
            complete?(image, duration)
            return
        }
        
        guard let url = url, let videoThumbnailPath = videoThumbnailPath else {
            complete?(nil, nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let (duration, thumbnail) = createThumbnailOfVideo(url: url, saveTo: videoThumbnailPath)
            self.duration = duration
            self.image = thumbnail
            
            DispatchQueue.main.async {
                complete?(thumbnail, duration)
            }
        }
    }
}

fileprivate extension OCTMessageFile {
    func getImage(thumbPath: String?) -> UIImage? {
        guard let filePath = filePath() else {
            return nil
        }
        
        if isImage() {
            return UIImage(contentsOfFile: filePath)
        } else if isVideo() {
            return videoThumbnail(thumbPath: thumbPath)
        }
        return nil
    }
    
    func videoThumbnailPath(thumbPath: String?) -> String? {
        guard let thumbPath = thumbPath,
            isVideo(),
            let filePath: NSString = filePath() as NSString? else {
            return nil
        }
        
        if let fileName = ((filePath.lastPathComponent as NSString).deletingPathExtension as NSString).appendingPathExtension("jpg") {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: thumbPath, isDirectory:&isDirectory)
            do {
                if exists == false || isDirectory.boolValue == false {
                    try FileManager.default.createDirectory(atPath: thumbPath, withIntermediateDirectories: true, attributes: nil)
                }
                let path = (thumbPath as NSString).appendingPathComponent(fileName)
                return path
            }
            catch {
            }
        }
        return nil
    }
    
    func videoThumbnail(thumbPath: String?) -> UIImage? {
        guard let path = videoThumbnailPath(thumbPath: thumbPath) else {
            return nil
        }
        
        return UIImage(contentsOfFile: path)
    }
}

func createThumbnailOfVideo(url: URL, saveTo: String) -> (String?, UIImage?) {
    let asset = AVAsset(url: url)
    
    let sec = max(CMTimeGetSeconds(asset.duration), 1)
    let duration = mediaDurationFormatter.string(from: sec)
    
    let assetImgGenerate = AVAssetImageGenerator(asset: asset)
    assetImgGenerate.appliesPreferredTrackTransform = true
    //Can set this to improve performance if target size is known before hand
    //assetImgGenerate.maximumSize = CGSize(width,height)
    let time = CMTimeMakeWithSeconds(0.0, preferredTimescale: 1)
    do {
        let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
        let thumbnail = UIImage(cgImage: img)
        
        let toURL = URL(fileURLWithPath: saveTo)
        try thumbnail.jpegData(compressionQuality: 0.8)?.write(to: toURL)
        
        return (duration, thumbnail)
    } catch {
        print(error.localizedDescription)
        return (duration, nil)
    }
}
