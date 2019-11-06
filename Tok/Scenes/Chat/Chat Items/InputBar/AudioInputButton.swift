//
//  AudioInputButton.swift
//  Tok
//
//  Created by Bryce on 2018/12/23.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation
import Lottie

let millisecondsPerSecond: Double = 1000
let audioExtension = "ogg"

class AudioInputButton: UIButton {
    
    private let disposeBag = DisposeBag()
    
    var didRecord: ((URL, UInt) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func awakeFromNib() {
        setup()
    }
    
    func setup() {
        layer.borderColor = UIColor("#ADADAD").cgColor
        layer.borderWidth = 1.0 / UIScreen.main.scale
        layer.cornerRadius = 18
        layer.masksToBounds = true
        
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        setTitleColor(UIColor("#18181D"), for: .normal)
        setDefaultStyle()
        
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(self.longPress(recognizer:)))
        hold.minimumPressDuration = 0
        addGestureRecognizer(hold)
        
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification)
            .subscribe(onNext: { [weak self] _ in
                self?.recorder?.cancel()
            })
            .disposed(by: disposeBag)
    }
    
    private var isCancelSendAudioMessage = false
    private var recorder: FCAudioRecorder?
    static let maxRecordDuration: TimeInterval = 60
    
    var dataSource: ConversationDataSource?
    
    var isRecording: Bool {
        if let recorder = recorder {
            return recorder.isRecording
        } else {
            return false
        }
    }
    
    @objc
    func longPress(recognizer: UIGestureRecognizer) {
        let point = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            AudioManager.shared.stop(deactivateAudioSession: false)
            startRecordingIfGranted()
            setHoldDownStyle()
        case .changed:
            if layer.contains(point) {
                setHoldDownStyle()
                isCancelSendAudioMessage = false
                AudioInputingView.updateState(willCancel: false)
            } else {
                setTitle(NSLocalizedString("Release to Cancel", comment: ""), for: .normal)
                AudioInputingView.updateState(willCancel: true)
                isCancelSendAudioMessage = true
            }
        case .ended:
            if isCancelSendAudioMessage {
                recorder?.cancel()
            } else {
                recorder?.stop()
            }
            isCancelSendAudioMessage = false
            stopRecordAnimating()
            setDefaultStyle()
        default:
            break
        }
    }
    
    func setHoldDownStyle() {
        setBackgroundImage(UIColor("#D4D4DC").createImage(), for: .normal)
        setTitle(NSLocalizedString("Release to Send", comment: ""), for: .normal)
    }
    
    private func setDefaultStyle() {
        setBackgroundImage(UIColor.white.createImage(), for: .normal)
        setBackgroundImage(UIColor("#D4D4DC").createImage(), for: .highlighted)
        setTitle(NSLocalizedString("Hold to Talk", comment: ""), for: .normal)
        setTitle(NSLocalizedString("Release to Send", comment: ""), for: .highlighted)
    }
    
    private func startRecordAnimating() {
        AudioInputingView.showInWindow()
    }
    
    private func stopRecordAnimating() {
        AudioInputingView.hideInWindow()
    }
}

extension AudioInputButton: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return recorder == nil
    }
}

extension AudioInputButton {
    
    private func startRecordingIfGranted() {
        startRecordAnimating()
        
        let recordPermission = AVAudioSession.sharedInstance().recordPermission
        switch recordPermission {
        case .denied:
            print("denied")
            stopRecordAnimating()
        case .granted:
            startRecording()
        case .undetermined:
            stopRecordAnimating()
            AVAudioSession.sharedInstance().requestRecordPermission { _ in
            }
        @unknown default:
            fatalError()
        }
    }
    
    private func startRecording() {
        let tempUrl = URL.createTempUrl(fileExtension: audioExtension)
        do {
            recorder = try FCAudioRecorder(path: tempUrl.path)
            recorder!.record(forDuration: AudioInputButton.maxRecordDuration, progress: { (progress) in
                switch progress {
                case .waitingForActivation:
                    break
                case .started:
                    break
                case .interrupted:
                    self.recorder?.cancel()
                @unknown default:
                    fatalError()
                }
            }) { (completion, metadata, error) in
                switch completion {
                case .failed:
                    break
                case .finished:
                    self.setDefaultStyle()
                    if let duration = metadata?.duration, Double(duration) > millisecondsPerSecond {
                        self.didRecord?(tempUrl, duration)
                    } else {
                        try? FileManager.default.removeItem(at: tempUrl)
                    }
                case .cancelled:
                    break
                @unknown default:
                    fatalError()
                }
                self.recorder = nil
                self.stopRecordAnimating()
                self.setDefaultStyle()
            }
        } catch {
            //            UIApplication.trackError(String(reflecting: self), action: #function, userInfo: ["error": error])
        }
    }
}

extension URL {
    static func createTempUrl(fileExtension: String) -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString.lowercased()).\(fileExtension)")
    }
    static func createDocumentUrl(fileExtension: String) -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: documentsPath).appendingPathComponent("\(UUID().uuidString.lowercased()).\(fileExtension)")
    }
}

class AudioInputingView: UIView {
    
    lazy var cancelView: UIImageView = {
        let imageView = UIImageView()
        imageView.isHidden = true
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "AudioInputCancel")
        return imageView
    }()
    
    lazy var animationView: AnimationView = {
        let animationView = AnimationView(name: "loading")
        animationView.loopMode = .loop
        return animationView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .white
        
        layer.cornerRadius = 32
        layer.borderColor = UIColor("#E1E1E1").cgColor
        layer.borderWidth = 1.0
        layer.masksToBounds = true
        
        addSubview(animationView)
        animationView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 31, height: 28))
            make.center.equalToSuperview()
        }
        
        addSubview(cancelView)
        cancelView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 25, height: 22))
        }
        
        update(willCancel: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(willCancel: Bool) {
        if willCancel {
            animationView.isHidden = true
            animationView.pause()
            cancelView.isHidden = false
        } else {
            animationView.isHidden = false
            animationView.play()
            cancelView.isHidden = true
        }
    }
    
    private static let bgViewTag = 66669999
    private static let inputingViewTag = 66669998
    private static let tipLabelTag = 66669997
    
    static func showInWindow() {
        let window = UIApplication.shared.keyWindow!
        guard window.viewWithTag(bgViewTag) == nil else {
            return
        }
        
        let bgView = UIView(frame: window.bounds)
        bgView.backgroundColor = .clear
        bgView.tag = bgViewTag
        window.addSubview(bgView)
        let tipView = AudioInputingView()
        tipView.tag = inputingViewTag
        bgView.addSubview(tipView)
        tipView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 64, height: 64))
            make.bottom.equalTo(bgView.safeArea.bottom).offset(-84)
            make.centerX.equalToSuperview()
        }
        
        let tipLabel: UILabel = {
            let label = UILabel()
            label.tag = tipLabelTag
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = UIColor.white
            label.text = NSLocalizedString("Slide up to Cancel", comment: "")
            label.sizeToFit()
            return label
        }()
        
        let blur = UIBlurEffect(style: UIBlurEffect.Style.dark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.layer.cornerRadius = 4
        blurView.layer.masksToBounds = true
        blurView.contentView.addSubview(tipLabel)
        tipLabel.snp.makeConstraints { (make) in
            make.edges.equalTo(UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        }
        
        bgView.addSubview(blurView)
        blurView.snp.makeConstraints { (make) in
            make.bottom.equalTo(tipView.snp.top).offset(-12)
            make.centerX.equalToSuperview()
        }
    }
    
    static func hideInWindow() {
        let window = UIApplication.shared.keyWindow!
        let view = window.viewWithTag(bgViewTag)
        view?.removeFromSuperview()
    }
    
    static func updateState(willCancel: Bool) {
        let window = UIApplication.shared.keyWindow!
        guard let bgView = window.viewWithTag(bgViewTag),
        let inputingView = bgView.viewWithTag(inputingViewTag) as? AudioInputingView,
        let tipLabel = bgView.viewWithTag(tipLabelTag) as? UILabel else {
            return
        }
        
        inputingView.update(willCancel: willCancel)
        tipLabel.text = willCancel ? NSLocalizedString("Release to Cancel", comment: "") : NSLocalizedString("Slide up to Cancel", comment: "")
    }
}
