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

extension UICollectionViewCell: Reusable {}

class PhotoMessageCell: OperationMessageCell {
    
    private var disposeBag = DisposeBag()
    
    func bind(with model: MediaModel) {
        disposeBag = DisposeBag()
        
        status = model.status.value
        
        switch status {
        case .failed, .success:
            if let image = model.image {
                imageView.image = image
            } else {
                imageView.image = UIImage(named: "ImageFailed")
            }
        case .loading:
            model.progress
                .distinctUntilChanged()
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] progress in
                    self?.progressView.progress = CGFloat(progress)
                })
                .disposed(by: disposeBag)
        case .waiting:
            break
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}
