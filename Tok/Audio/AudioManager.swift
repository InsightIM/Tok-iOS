import Foundation
import AVFoundation
import ChattoAdditions

class AudioManager {
    
    struct Node {
        let message: MessageModelProtocol
        let path: String
    }
    
    static let shared = AudioManager()
    
    let player = FCAudioPlayer.shared()
    
    private(set) var playingNode: Node?
    
    private let queue = DispatchQueue(label: "com.insight.tok.audio_manager")
    
    private var cells = NSMapTable<NSString, AudioMessageCollectionViewCell>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var isPlayingObservation: NSKeyValueObservation?
    
    init() {
        isPlayingObservation = player.observe(\.isPlaying) { [weak self] (player, change) in
            self?.isPlayingChanged()
        }
    }
    
    deinit {
        isPlayingObservation?.invalidate()
    }
    
    func playOrStop(node: Node) {
        let key = node.message.uid as NSString
        if playingNode?.message.uid == node.message.uid {
            cells.object(forKey: key)?.bubbleView?.isPlaying = false
            stop(deactivateAudioSession: true)
        } else {
            if let cells = cells.objectEnumerator()?.allObjects as? [AudioMessageCollectionViewCell] {
                cells.forEach {
                    $0.bubbleView.isPlaying = false
                }
            }
            cells.object(forKey: key)?.bubbleView?.isPlaying = true
            queue.async {
                let center = NotificationCenter.default
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .default, options: [])
                    try session.setActive(true, options: [])
                    center.addObserver(self,
                                       selector: #selector(AudioManager.audioSessionInterruption(_:)),
                                       name: AVAudioSession.interruptionNotification,
                                       object: nil)
                    center.addObserver(self,
                                       selector: #selector(AudioManager.audioSessionRouteChange(_:)),
                                       name: AVAudioSession.routeChangeNotification,
                                       object: nil)
                    center.addObserver(self,
                                       selector: #selector(AudioManager.audioSessionMediaServicesWereReset(_:)),
                                       name: AVAudioSession.mediaServicesWereResetNotification,
                                       object: nil)
                    self.playingNode = nil
                    try self.player.loadFile(atPath: node.path)
                    self.player.play()
                    self.playingNode = node
                } catch {
                    self.cells.object(forKey: key)?.bubbleView?.isPlaying = false
                    center.removeObserver(self)
                    return
                }
            }
        }
    }
    
    func stop(deactivateAudioSession: Bool) {
        queue.async {
            guard self.player.isPlaying else {
                return
            }
            self.updateCellsAndPlayingNodeForStopping()
            self.player.stop()
            NotificationCenter.default.removeObserver(self)
            if deactivateAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
    
    func register(cell: AudioMessageCollectionViewCell, forMessageId messageId: String) {
        cells.setObject(cell, forKey: messageId as NSString)
        cell.bubbleView.isPlaying = messageId == playingNode?.message.uid
    }
    
    func unregister(cell: AudioMessageCollectionViewCell, forMessageId messageId: String) {
        let key = messageId as NSString
        guard self.cells.object(forKey: key) == cell else {
            return
        }
        cells.removeObject(forKey: key)
    }
    
    @objc func audioSessionInterruption(_ notification: Notification) {
        stop(deactivateAudioSession: true)
    }
    
    @objc func audioSessionRouteChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? AVAudioSession.RouteChangeReason else {
            return
        }
        switch reason {
        case .override, .newDeviceAvailable, .routeConfigurationChange:
            break
        case .categoryChange:
            let newCategory = AVAudioSession.sharedInstance().category
            let canContinue = newCategory == .playback || newCategory == .playAndRecord
            if !canContinue {
                stop(deactivateAudioSession: true)
            }
        case .unknown, .oldDeviceUnavailable, .wakeFromSleep, .noSuitableRouteForCategory:
            stop(deactivateAudioSession: true)
        @unknown default:
            fatalError()
        }
    }
    
    @objc func audioSessionMediaServicesWereReset(_ notification: Notification) {
        player.dispose()
    }
    
    private func updateCellsAndPlayingNodeForStopping() {
        performSynchronouslyOnMainThread {
            if let messageId = self.playingNode?.message.uid {
                self.cells.object(forKey: messageId as NSString)?.bubbleView.isPlaying = false
            }
            self.playingNode = nil
        }
    }
    
    private func isPlayingChanged() {
        guard !player.isPlaying else {
            return
        }
        guard let messageId = playingNode?.message.uid else {
            return
        }
        performSynchronouslyOnMainThread {
            cells.object(forKey: messageId as NSString)?.bubbleView?.isPlaying = false
        }
        if let node = playingNode, let nextNode = self.node(nextTo: node) {
            performSynchronouslyOnMainThread {
                playOrStop(node: nextNode)
            }
        } else {
            updateCellsAndPlayingNodeForStopping()
            NotificationCenter.default.removeObserver(self)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    private func node(nextTo node: Node) -> Node? {
        return nil
    }
    
//    private func node(nextTo node: Node) -> Node? {
//        guard let nextMessage = MessageDAO.shared.getMessages(conversationId: node.message.conversationId, belowMessage: node.message, count: 1).first else {
//            return nil
//        }
//        guard nextMessage.category.hasSuffix("_AUDIO"), nextMessage.userId == node.message.userId else {
//            return nil
//        }
//        guard let filename = nextMessage.mediaUrl else {
//            return nil
//        }
//        let path = MixinFile.url(ofChatDirectory: .audios, filename: filename).path
//        return Node(message: nextMessage, path: path)
//    }
    
}
