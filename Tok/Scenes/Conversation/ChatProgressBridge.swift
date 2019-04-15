import Foundation

protocol ChatProgressProtocol {
    var updateProgress: ((_ progress: Float, _ message: OCTMessageAbstract) -> Void)? { get set }
    var updateEta: ((_ eta: CFTimeInterval, _ bytesPerSecond: OCTToxFileSize) -> Void)? { get set }
}

/**
    Bridge between objcTox subscriber and chat progress protocol.
 */
class ChatProgressBridge: NSObject, ChatProgressProtocol {
    var updateProgress: ((_ progress: Float, _ message: OCTMessageAbstract) -> Void)?
    var updateEta: ((_ eta: CFTimeInterval, _ bytesPerSecond: OCTToxFileSize) -> Void)?
}

extension ChatProgressBridge: OCTSubmanagerFilesProgressSubscriber {
    func submanagerFiles(onProgressUpdate progress: Float, message: OCTMessageAbstract) {
        updateProgress?(progress, message)
    }

    func submanagerFiles(onEtaUpdate eta: CFTimeInterval, bytesPerSecond: OCTToxFileSize, message: OCTMessageAbstract) {
        updateEta?(eta, bytesPerSecond)
    }
}
