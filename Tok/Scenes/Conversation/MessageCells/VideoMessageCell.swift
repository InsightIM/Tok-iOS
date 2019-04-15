//
//  VideoMessageCell.swift
//  Tok
//
//  Created by Bryce on 2019/3/21.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation

class VideoMessageCell: OperationMessageCell {
    
    private var disposeBag = DisposeBag()
    
    lazy var playButton: UIButton = {
        let button = UIButton()
        button.isUserInteractionEnabled = false
        button.setImage(UIImage(named: "VideoPlay"), for: .normal)
        return button
    }()
    
    lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 10, weight: .light)
        label.textColor = .white
        return label
    }()
    
    lazy var bottomShadowView: UIView = {
        let imageView = UIImageView()
        imageView.contentMode = .bottomRight
        imageView.image = UIImage(named: "VideoShadow")
        return imageView
    }()
    
    override func setupSubviews() {
        super.setupSubviews()
        
        messageContainerView.addSubview(playButton)
        playButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }
        
        messageContainerView.addSubview(bottomShadowView)
        bottomShadowView.snp.makeConstraints { (make) in
            make.bottom.left.right.equalToSuperview()
            make.height.equalTo(76)
        }
        
        messageContainerView.addSubview(durationLabel)
        durationLabel.snp.makeConstraints { (make) in
            make.right.equalTo(-5)
            make.bottom.equalTo(-5)
        }
    }
    
    func bind(with model: MediaModel) {
        disposeBag = DisposeBag()
        
        status = model.status.value
        
        switch status {
        case .failed:
            playButton.isHidden = !isOutgoing
            durationLabel.isHidden = !isOutgoing
            
            setImageAndDuration(model: model, isOutgoing: isOutgoing, placeholder: UIImage(named: "ImageFailed"))
        case .loading:
            playButton.isHidden = true
            durationLabel.isHidden = false
            
            model.progress
                .distinctUntilChanged()
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] progress in
                    self?.progressView.progress = CGFloat(progress)
                })
                .disposed(by: disposeBag)
        case .success:
            playButton.isHidden = false
            durationLabel.isHidden = false
            
            setImageAndDuration(model: model, isOutgoing: isOutgoing)
        case .waiting:
            playButton.isHidden = true
            durationLabel.isHidden = !isOutgoing
            
            setImageAndDuration(model: model, isOutgoing: isOutgoing)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
    
    private func setImageAndDuration(model: MediaModel, isOutgoing: Bool, placeholder: UIImage? = nil) {
        model.fetchThumbnailAndDuration { [weak self] (image, duration) in
            self?.imageView.image = image ?? (isOutgoing ? nil : placeholder)
            self?.durationLabel.text = duration
        }
    }
}
