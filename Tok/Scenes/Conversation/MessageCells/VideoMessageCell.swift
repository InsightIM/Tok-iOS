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
    
    func bind(with model: MediaModel) {
        disposeBag = DisposeBag()
        
        status = model.status.value
        
        switch status {
        case .failed:
            sizeLabel.isHidden = !isOutgoing
            placeholder.isHidden = isOutgoing
            imageView.isHidden = !isOutgoing
            setImageAndDuration(model: model, isOutgoing: isOutgoing)
        case .loading:
            sizeLabel.isHidden = false
            placeholder.isHidden = false
            imageView.isHidden = !isOutgoing
            model.progress
                .distinctUntilChanged()
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] progress in
                    self?.operationButton.style = .busy(progress: Double(progress))
                })
                .disposed(by: disposeBag)
        case .success:
            sizeLabel.isHidden = false
            placeholder.isHidden = false
            imageView.isHidden = false
            setImageAndDuration(model: model, isOutgoing: isOutgoing)
        case .waiting:
            sizeLabel.isHidden = false
            placeholder.isHidden = isOutgoing
            imageView.isHidden = !isOutgoing
            setImageAndDuration(model: model, isOutgoing: isOutgoing)
        case .expired:
            sizeLabel.isHidden = true
            placeholder.isHidden = isOutgoing
            imageView.isHidden = !isOutgoing
            imageView.image = nil
            placeholder.image = UIImage(named: "VideoExpired")
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
    
    private func setImageAndDuration(model: MediaModel, isOutgoing: Bool) {
        model.fetchThumbnailAndDuration { [weak self] (image, duration) in
            if let img = image {
                self?.imageView.image = img
            } else {
                self?.imageView.image = nil
                self?.placeholder.image = model.placeholderImage
            }
            self?.sizeLabel.text = model.status.value == .success ? duration : model.fileSize
        }
    }
}
