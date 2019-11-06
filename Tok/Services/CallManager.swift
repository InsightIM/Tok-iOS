import Foundation

protocol CallCoordinatorDelegate: class {
    func callCoordinator(_ coordinator: CallManager, notifyAboutBackgroundCallFrom caller: OCTCall, userInfo: String)
    func callCoordinatorDidStartCall(_ coordinator: CallManager)
    func callCoordinatorDidFinishCall(_ coordinator: CallManager)
}

private struct Constants {
    static let DeclineAfterInterval = 1.5
}

private class ActiveCall {
    var callToken: RLMNotificationToken?
    
    fileprivate let call: OCTCall
    fileprivate let navigation: UINavigationController
    
    fileprivate var usingFrontCamera: Bool = true
    
    init(call: OCTCall, navigation: UINavigationController) {
        self.call = call
        self.navigation = navigation
    }
    
    deinit {
        callToken?.invalidate()
    }
}

class CallManager: NSObject {
    weak var delegate: CallCoordinatorDelegate?
    
    fileprivate weak var presentingController: UIViewController!
    fileprivate weak var submanagerCalls: OCTSubmanagerCalls!
    fileprivate weak var submanagerObjects: OCTSubmanagerObjects!
    
    fileprivate let audioPlayer = AudioPlayer()
    
    fileprivate var activeCall: ActiveCall? {
        didSet {
            switch (oldValue, activeCall) {
            case (.none, .some):
                delegate?.callCoordinatorDidStartCall(self)
            case (.some, .none):
                delegate?.callCoordinatorDidFinishCall(self)
            default:
                break
            }
        }
    }
    
    let messageService: MessageService
    init(presentingController: UIViewController, messageService: MessageService) {
        self.presentingController = presentingController
        self.messageService = messageService
        self.submanagerCalls = messageService.tokManager.toxManager.calls
        self.submanagerObjects = messageService.tokManager.toxManager.objects
        
        super.init()
        
        submanagerCalls.delegate = self
    }
    
    func callToChat(_ chat: OCTChat, enableVideo: Bool) {
        do {
            let call = try submanagerCalls.call(to: chat, enableAudio: true, enableVideo: enableVideo)
            let controller = CallActiveController(call: call, messageService: messageService)
            controller.delegate = self
            
            startActiveCallWithCall(call, controller: controller)
        }
        catch let error as NSError {
            print("\(error)")
            ProgressHUD.showTextHUD(withText: error.localizedFailureReason ?? error.localizedDescription, in: presentingController.view)
        }
    }
    
    func answerIncomingCallWithUserInfo(_ userInfo: String) {
        guard let activeCall = activeCall else { return }
        guard activeCall.call.uniqueIdentifier == userInfo else { return }
        guard activeCall.call.status == .ringing else { return }
        
        answerCall(enableVideo: false)
    }
}

extension CallManager: OCTSubmanagerCallDelegate {
    func callSubmanager(_ callSubmanager: OCTSubmanagerCalls!, receive call: OCTCall!, audioEnabled: Bool, videoEnabled: Bool) {
        guard activeCall == nil else {
            // Currently we support only one call at a time
            _ = try? submanagerCalls.send(.cancel, to: call)
            return
        }
        
        if !UIApplication.isActive {
            delegate?.callCoordinator(self, notifyAboutBackgroundCallFrom: call, userInfo: call.uniqueIdentifier)
        }
        
        let controller = CallIncomingController(call: call, messageService: messageService)
        controller.delegate = self
        
        startActiveCallWithCall(call, controller: controller)
    }
}

extension CallManager: CallIncomingControllerDelegate {
    func callIncomingControllerDecline(_ controller: CallIncomingController) {
        declineCall(callWasRemoved: false)
    }
    
    func callIncomingControllerAnswerAudio(_ controller: CallIncomingController) {
        answerCall(enableVideo: false)
    }
    
    func callIncomingControllerAnswerVideo(_ controller: CallIncomingController) {
        answerCall(enableVideo: true)
    }
}

extension CallManager: CallActiveControllerDelegate {
    func callActiveController(_ controller: CallActiveController, mute: Bool) {
        submanagerCalls.enableMicrophone = !mute
    }
    
    func callActiveController(_ controller: CallActiveController, speaker: Bool) {
        do {
            try submanagerCalls.routeAudio(toSpeaker: speaker)
        }
        catch {
//            handleErrorWithType(.routeAudioToSpeaker)
            controller.speaker = !speaker
        }
    }
    
    func callActiveController(_ controller: CallActiveController, outgoingVideo: Bool) {
        guard let activeCall = activeCall else {
            assert(false, "This method should be called only if active call is non-nil")
            return
        }
        
        do {
            try submanagerCalls.enableVideoSending(outgoingVideo, for: activeCall.call)
        }
        catch {
//            handleErrorWithType(.enableVideoSending)
            controller.outgoingVideo = !outgoingVideo
        }
    }
    
    func callActiveControllerDecline(_ controller: CallActiveController) {
        declineCall(callWasRemoved: false)
    }
    
    func callActiveControllerSwitchCamera(_ controller: CallActiveController) {
        guard let activeCall = activeCall else {
            assert(false, "This method should be called only if active call is non-nil")
            return
        }
        
        do {
            let front = !activeCall.usingFrontCamera
            try submanagerCalls.switch(toCameraFront: front)
            
            self.activeCall?.usingFrontCamera = front
        }
        catch {
//            handleErrorWithType(.callSwitchCamera)
        }
    }
}

private extension CallManager {
    func declineCall(callWasRemoved wasRemoved: Bool) {
        guard let activeCall = activeCall else {
            assert(false, "This method should be called only if active call is non-nil")
            return
        }
        
        if !wasRemoved {
            _ = try? submanagerCalls.send(.cancel, to: activeCall.call)
        }
        
        audioPlayer.stopAll()
        
        if let controller = activeCall.navigation.topViewController as? CallBaseController {
            controller.prepareForRemoval()
        }
        
        let delayTime = DispatchTime.now() + Double(Int64(Constants.DeclineAfterInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime) { [weak self] in
            self?.presentingController.dismiss(animated: true, completion: nil)
            self?.activeCall = nil
        }
    }
    
    func startActiveCallWithCall(_ call: OCTCall, controller: CallBaseController) {
        guard activeCall == nil else {
            assert(false, "This method should be called only if there is no active call")
            return
        }
        
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .overCurrentContext
        navigation.isNavigationBarHidden = true
        navigation.modalTransitionStyle = .crossDissolve
        
        activeCall = ActiveCall(call: call, navigation: navigation)
        
        let predicate = NSPredicate(format: "uniqueIdentifier == %@", call.uniqueIdentifier)
        let results = submanagerObjects.calls(predicate: predicate)
        activeCall!.callToken = results.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update(_, let deletions, _, let modifications):
                if deletions.count > 0 {
                    self.declineCall(callWasRemoved: true)
                }
                else if modifications.count > 0 {
                    self.activeCallWasUpdated()
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        presentingController.present(navigation, animated: true, completion: nil)
        activeCallWasUpdated()
    }
    
    func answerCall(enableVideo: Bool) {
        guard let activeCall = activeCall else {
            assert(false, "This method should be called only if active call is non-nil")
            return
        }
        
        guard activeCall.call.status == .ringing else {
            assert(false, "Call status should be .Ringing")
            return
        }
        
        do {
            try submanagerCalls.answer(activeCall.call, enableAudio: true, enableVideo: enableVideo)
        }
        catch let error as NSError {
//            handleErrorWithType(.answerCall, error: error)
            print("\(error)")
            declineCall(callWasRemoved: false)
        }
    }
    
    func activeCallWasUpdated() {
        guard let activeCall = activeCall else {
            assert(false, "This method should be called only if active call is non-nil")
            return
        }
        
        guard activeCall.call.isInvalidated == false else {
            return
        }
        
        switch activeCall.call.status {
        case .ringing:
            if !audioPlayer.isPlayingSound(.Ringtone) {
                audioPlayer.playSound(.Ringtone, loop: true)
            }
            
            // no update for ringing status
            return
        case .dialing:
            if !audioPlayer.isPlayingSound(.Calltone) {
                audioPlayer.playSound(.Calltone, loop: true)
            }
        case .active:
            if audioPlayer.isPlaying() {
                audioPlayer.stopAll()
            }
        @unknown default:
            fatalError()
        }
        
        var activeController = activeCall.navigation.topViewController as? CallActiveController
        
        if (activeController == nil) {
            activeController = CallActiveController(call: activeCall.call, messageService: messageService)
            activeController!.delegate = self
            
            activeCall.navigation.setViewControllers([activeController!], animated: false)
        }
        
        switch activeCall.call.status {
        case .ringing:
            break
        case .dialing:
            activeController!.state = .reaching
        case .active:
            activeController!.state = .active(duration: activeCall.call.callDuration)
        @unknown default:
            fatalError()
        }
        
        activeController!.outgoingVideo = activeCall.call.videoIsEnabled
        if activeCall.call.videoIsEnabled {
            if activeController!.videoPreviewLayer == nil {
                submanagerCalls.getVideoCallPreview { [weak activeController] layer in
                    activeController?.videoPreviewLayer = layer
                }
            }
        }
        else {
            if activeController!.videoPreviewLayer != nil {
                activeController!.videoPreviewLayer = nil
            }
        }
        
        if activeCall.call.friendSendingVideo {
            if activeController!.videoFeed == nil {
                activeController!.videoFeed = submanagerCalls.videoFeed()
            }
        }
        else {
            if activeController!.videoFeed != nil {
                activeController!.videoFeed = nil
            }
        }
    }
}
