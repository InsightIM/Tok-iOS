//
//  VideoPreviewViewController.swift
//  Tok
//
//  Created by Bryce on 2019/4/4.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class VideoPreviewViewController: UIViewController {

    var didSendFile: ((URL) -> Void)?
    
    private var videoURL: URL
    var player: AVPlayer?
    var playerController : AVPlayerViewController?
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "GoBack"), for: UIControl.State())
        button.addTarget(self, action: #selector(cancelClick), for: .touchUpInside)
        return button
    }()
    
    lazy var sendButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "Tick"), for: UIControl.State())
        button.addTarget(self, action: #selector(sendClick), for: .touchUpInside)
        return button
    }()
    
    var cancelView: UIView!
    var sendView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        player = AVPlayer(url: videoURL)
        playerController = AVPlayerViewController()
        
        guard let player = player, let playerController = playerController else {
            return
        }
        
        playerController.showsPlaybackControls = false
        
        playerController.player = player
        playerController.view.frame = view.bounds
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player!.currentItem)
        
        // Allow background audio to continue to play
        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: .default, options: [])
            } else {
            }
        } catch let error as NSError {
            print(error)
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error as NSError {
            print(error)
        }
        
        cancelView = cancelButton.setupBlurButton()
        sendView = sendButton.setupBlurButton()
        
        view.addSubview(cancelView)
        cancelView.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            make.size.equalTo(80)
            make.centerX.equalToSuperview().multipliedBy(0.4)
        }
        
        view.addSubview(sendView)
        sendView.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            make.size.equalTo(80)
            make.centerX.equalToSuperview().multipliedBy(1.6)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        player?.play()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc func sendClick() {
        convertToMP4(fileURL: videoURL)
    }
    
    @objc func cancelClick() {
        dismiss(animated: false, completion: nil)
    }
    
    @objc fileprivate func playerItemDidReachEnd(_ notification: Notification) {
        if self.player != nil {
            self.player!.seek(to: CMTime.zero)
            self.player!.play()
        }
    }
    
    private func convertToMP4(fileURL: URL) {
        ProgressHUD.showLoadingHUD(in: self.view)
        
        let avAsset = AVURLAsset(url: fileURL, options: nil)
        
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let destinationPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension("mp4")
        let exporter = AVAssetExportSession(asset: avAsset,
                                            presetName: AVAssetExportPresetMediumQuality)!
        exporter.outputURL = destinationPath
        exporter.outputFileType = AVFileType.mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.exportAsynchronously(completionHandler: { [weak self] in
            DispatchQueue.main.async {
                ProgressHUD.hideLoadingHUD(in: self?.view)
                self?.didSendFile?(destinationPath)
                self?.dismiss(animated: false, completion: nil)
            }
        })
    }
}
