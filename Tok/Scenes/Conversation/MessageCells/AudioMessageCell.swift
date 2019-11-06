//
//  AudioMessageCell.swift
//  Tok
//
//  Created by Bryce on 2018/10/11.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import AVFoundation

class AudioMessageCell: OperationMessageCell {
    
    var messageStatus: MessageStatus = .waiting {
        didSet {
            switch messageStatus {
            case .failed, .waiting, .unread:
                statusImageView.image = nil
            case .sending, .sent:
                statusImageView.image = UIImage(named: messageStatus.imageName)
            }
        }
    }
    
    lazy var waveImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.tokBlack
        return imageView
    }()
    
    lazy var statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var lengthLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    /// Responsible for setting up the constraints of the cell's subviews.
    open override func setupConstraints() {
        operationButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }
    }
    
    override func setupCustomViews() {
        messageContainerView.addSubview(waveImageView)
        messageContainerView.addSubview(lengthLabel)
        messageContainerView.addSubview(statusImageView)
        messageContainerView.addSubview(operationButton)
        
        setupConstraints()
    }
    
    private var disposeBag = DisposeBag()
    
    func bind(with model: AudioMessageModel) {
        disposeBag = DisposeBag()
        
        status = model.status.value
        
        lengthLabel.text = model.length
        
        let player = FCAudioPlayer.shared()        
        switch player.state {
        case .preparing, .readyToPlay, .playing:
            let filePath = model.path
            if let filePath = filePath,
                player.path == filePath {
                isPlaying = true
            }
        default:
            break
        }
        
        model.status
            .distinctUntilChanged()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .failed, .expired:
                    self.operationButton.style = .finished(showPlayIcon: false)
                    self.messageStatus = .failed
                case .loading:
                    self.operationButton.style = .busy(progress: 0)
                    self.messageStatus = .sending
                    
                    model.progress
                        .distinctUntilChanged()
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { [weak self] progress in
                            self?.operationButton.style = .busy(progress: Double(progress))
                        })
                        .disposed(by: self.disposeBag)
                case .success:
                    self.operationButton.style = .finished(showPlayIcon: false)
                    self.messageStatus = .sent
                case .waiting:
                    self.operationButton.style = self.isOutgoing ? .upload : .download
                    self.messageStatus = .waiting
                }
            })
            .disposed(by: disposeBag)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
        
        isPlaying = false
    }
    
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else {
                return
            }
            
            if isPlaying {
                FCAudioPlayer.shared().addObserver(self)
                startAnimation()
            } else {
                FCAudioPlayer.shared().removeObserver(self)
                stopAnimation()
            }
        }
    }
    
    open func startAnimation() {
    }
    
    open func stopAnimation() {
    }
}

extension AudioMessageCell: FCAudioPlayerObserver {
    
    func fcAudioPlayer(_ player: FCAudioPlayer, playbackStateDidChangeTo state: FCAudioPlaybackState) {
        if state == .stopped {
            if Thread.isMainThread {
                isPlaying = false
            } else {
                DispatchQueue.main.sync { [weak self] in
                    self?.isPlaying = false
                }
            }
        }
    }
}

class AudioIncomingCell: AudioMessageCell {
    override func setupConstraints() {
        super.setupConstraints()
        
        waveImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 12, height: 16))
            make.right.equalTo(-10)
            make.centerY.equalToSuperview()
        }
        
        lengthLabel.snp.makeConstraints { (make) in
            make.centerY.equalTo(waveImageView)
            make.right.equalTo(waveImageView.snp.left).offset(-8)
        }
        
        statusImageView.snp.makeConstraints { (make) in
            make.left.equalTo(12)
            make.bottom.equalTo(-6)
            make.size.equalTo(CGSize(width: 10, height: 10))
        }
        
        waveImageView.image = UIImage(named: "AudioReceiverPlay_03")
    }
    
    override func startAnimation() {
        waveImageView.animationImages = [UIImage(named: "AudioReceiverPlay_01")!, UIImage(named: "AudioReceiverPlay_02")!, UIImage(named: "AudioReceiverPlay_03")!]
        waveImageView.animationDuration = 1.0
        waveImageView.startAnimating()
    }
    
    override func stopAnimation() {
        waveImageView.animationImages = nil
        waveImageView.stopAnimating()
    }
}

class AudioOutgoingCell: AudioMessageCell {
    override func setupConstraints() {
        super.setupConstraints()
        
        waveImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 12, height: 16))
            make.left.equalTo(10)
            make.centerY.equalToSuperview()
        }
        
        lengthLabel.snp.makeConstraints { (make) in
            make.centerY.equalTo(waveImageView)
            make.left.equalTo(waveImageView.snp.right).offset(8)
        }
        
        statusImageView.snp.makeConstraints { (make) in
            make.right.equalTo(-12)
            make.bottom.equalTo(-6)
            make.size.equalTo(CGSize(width: 10, height: 10))
        }
        
        waveImageView.image = UIImage(named: "AudioSenderPlay_03")
    }
    
    override func startAnimation() {
        waveImageView.animationImages = [UIImage(named: "AudioSenderPlay_01")!, UIImage(named: "AudioSenderPlay_02")!, UIImage(named: "AudioSenderPlay_03")!]
        waveImageView.animationDuration = 1.0
        waveImageView.startAnimating()
    }
    
    override func stopAnimation() {
        waveImageView.stopAnimating()
        waveImageView.animationImages = nil
    }
}
