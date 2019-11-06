//
//  PhotoMediaMessageCellCollectionViewCell.swift
//  Tok
//
//  Created by Bryce on 2018/9/30.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import Reusable
import RxSwift
import RxCocoa
import YYImage

extension UICollectionViewCell: Reusable {}

class PhotoMessageCell: OperationMessageCell {
    
    private var disposeBag = DisposeBag()
    
    func bind(with model: MediaModel) {
        disposeBag = DisposeBag()
        
        status = model.status.value
        
        switch status {
        case .waiting, .failed:
            if model.isOutgoing {
                if let filePath = model.url?.path, let image = YYImage(contentsOfFile: filePath) {
                    imageView.image = image
                    imageView.isHidden = false
                    placeholder.isHidden = true
                    break
                }
            }
            
            imageView.image = nil
            placeholder.image = model.placeholderImage
            imageView.isHidden = true
            placeholder.isHidden = false
        case .success:
            if let filePath = model.url?.path, let image = YYImage(contentsOfFile: filePath) {
                imageView.image = image
                imageView.isHidden = false
                placeholder.isHidden = true
            } else {
                imageView.image = nil
                placeholder.image = model.placeholderImage
                imageView.isHidden = true
                placeholder.isHidden = false
            }
        case .loading:
            imageView.isHidden = !isOutgoing
            placeholder.image = model.placeholderImage
            model.progress
                .distinctUntilChanged()
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] progress in
                    self?.operationButton.style = .busy(progress: Double(progress))
                })
                .disposed(by: disposeBag)
        case .expired:
            imageView.image = nil
            placeholder.image = UIImage(named: "PhotoExpired")
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}
