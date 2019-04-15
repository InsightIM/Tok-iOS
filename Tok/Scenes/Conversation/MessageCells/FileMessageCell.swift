//
//  FileMessageCell.swift
//  Tok
//
//  Created by Bryce on 2018/10/3.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

class FileMessageCell: OperationMessageCell {
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.font = UIFont.systemFont(ofSize: 15)
        return label
    }()
    
    lazy var bottomLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#B8B8B8")
        label.font = UIFont.systemFont(ofSize: 13)
        return label
    }()
    
    lazy var extenView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.image = UIImage(named: "FiletypeDefault")
        return view
    }()
    
    lazy var extenLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 15)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Methods
    
    /// Responsible for setting up the constraints of the cell's subviews.
    override func setupConstraints() {
        extenView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 50, height: 56))
            make.left.equalTo(8)
            make.centerY.equalToSuperview()
        }
        
        extenLabel.snp.makeConstraints { (make) in
            make.left.equalTo(6)
            make.bottom.equalTo(-6)
        }
        
        marker.snp.makeConstraints { (make) in
            make.size.equalTo(extenView)
            make.center.equalTo(extenView)
        }
        
        operationButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(32)
        }
        
        progressView.snp.makeConstraints { (make) in
            make.size.equalTo(32)
            make.center.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview().offset(-12)
            make.left.equalTo(extenView.snp.right).offset(8)
            make.right.equalTo(-10)
        }
        
        bottomLabel.snp.makeConstraints { (make) in
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
            make.left.equalTo(nameLabel)
            make.right.equalTo(-10)
        }
    }
    
    override func setupCustomViews() {
        messageContainerView.addSubview(nameLabel)
        messageContainerView.addSubview(bottomLabel)
        messageContainerView.addSubview(extenView)
        extenView.addSubview(extenLabel)
        extenView.addSubview(marker)
        marker.addSubview(progressView)
        marker.addSubview(operationButton)
    }
    
    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let message = message as? MessageModel else {
            return
        }
        let left = message.isOutgoing ? 8 : 15
        extenView.snp.updateConstraints { (make) in
            make.left.equalTo(left)
        }
        
        isOutgoing = message.isOutgoing
        
        guard let _ = messagesCollectionView.messagesDisplayDelegate else {
            return
        }
        
        switch message.kind {
        case .file(let file):
            nameLabel.text = file.name
            bottomLabel.text = file.fileSize
            
            let exten = (file.name as NSString).pathExtension.uppercased()
            if exten.isEmpty || exten.count > 4 {
                extenLabel.text = "FILE"
            } else {
                extenLabel.text = exten
            }
        default:
            break
        }
    }
    
    private var disposeBag = DisposeBag()
    
    func bind(with file: FileMessageModel) {
        disposeBag = DisposeBag()
        
        status = file.status.value
        
        switch status {
        case .loading:
            file.progress
                .distinctUntilChanged()
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] progress in
                    self?.progressView.progress = CGFloat(progress)
                })
                .disposed(by: disposeBag)
        case .success, .failed, .waiting:
            break
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}
