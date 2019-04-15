//
//  FriendSelectionCell.swift
//  Tok
//
//  Created by Bryce on 2018/12/15.
//  Copyright © 2018年 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class FriendSelectionCell: UITableViewCell {

    lazy var selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Unselected")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var avatarImageView: AvatarImageView = {
        let imageView = AvatarImageView()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectedBackgroundView = UIView()
        selectionStyle = .none
        
        addSubview(selectionImageView)
        addSubview(avatarImageView)
        addSubview(nameLabel)
        
        selectionImageView.snp.makeConstraints { (make) in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(22)
        }
        
        avatarImageView.snp.makeConstraints { (make) in
            make.left.equalTo(selectionImageView.snp.right).offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
            make.right.equalTo(-10)
        }
        
        let lineView = UIView()
        lineView.backgroundColor = UIColor.tokLine
        addSubview(lineView)
        lineView.snp.makeConstraints { (make) in
            make.left.equalTo(16)
            make.right.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        guard !isDisabled else {
            return
        }
        selectionImageView.image = selected ? UIImage(named: "Selected") : UIImage(named: "Unselected")
    }
    
    internal var isDisabled: Bool = false
    
    private var disposeBag = DisposeBag()
    
    func render(viewModel: FriendSelectionViewModel) {
        avatarImageView.setFriendImage(friend: viewModel.friend)
        nameLabel.text = viewModel.name
        
        isDisabled = viewModel.isDisabled
        
        guard isDisabled == false else {
            selectionImageView.image = UIImage(named: "SelectionDisabled")
            return
        }
        
        isSelected = viewModel.isSelected.value
        
        viewModel.isSelected
            .subscribe(onNext: { [unowned self] selected in
                self.isSelected = selected
            })
            .disposed(by: disposeBag)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}
