//
//  GroupMemberListCell.swift
//  FChat
//
//  Created by zhanghanbing on 2019/1/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import Reusable

class GroupMemberListCell: UITableViewCell {

    var disposeBag = DisposeBag()
    
    private let padding = 16
    
    lazy var topView = GroupMemberListTopView()
    lazy var middleView = GroupMemberListMiddleView()
    lazy var bottomView = GroupMemberListBottomView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        
        contentView.addSubview(topView)
        topView.snp.makeConstraints { (make) in
            make.left.equalTo(padding)
            make.right.equalTo(-padding)
            make.top.equalToSuperview()
            make.height.equalTo(40)
        }
        
        contentView.addSubview(middleView.view)
        middleView.view.snp.makeConstraints { (make) in
            make.left.equalTo(padding)
            make.right.equalTo(-padding)
            make.top.equalTo(topView.snp.bottom).offset(3)
            make.height.equalTo(80).priorityHigh()
        }
        
        contentView.addSubview(bottomView)
        bottomView.snp.makeConstraints { (make) in
            make.left.equalTo(padding)
            make.right.equalTo(-padding)
            make.top.equalTo(middleView.view.snp.bottom)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }
        
        let lineView = UIView()
        lineView.backgroundColor = UIColor.tokLine
        contentView.addSubview(lineView)
        lineView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
            make.top.equalTo(bottomView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}

class GroupMemberListTopView: UIView {
    
    lazy var textLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#83838D")
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = NSLocalizedString("Group Members", comment: "")
        return label
    }()
    
    lazy var editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Edit", comment: ""), for: .normal)
        button.setTitleColor(.tokLink, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(textLabel)
        textLabel.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        addSubview(editButton)
        editButton.snp.makeConstraints { (make) in
            make.left.greaterThanOrEqualTo(textLabel.snp.right).offset(10)
            make.right.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GroupMemberCollectionViewCell: UICollectionViewCell {
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = UIColor.tokTitle4
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        
        avatarImageView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(48)
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.top.equalTo(avatarImageView.snp.bottom).offset(4)
            make.left.right.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GroupMemberListMiddleView: UICollectionViewController {
    
    var didSelect: ((Peer) -> Void)?
    
    var dataSource: [Peer]? {
        didSet {
            guard dataSource != nil else {
                return
            }
            
            self.collectionView.reloadData()
        }
    }
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 60, height: 80)
        layout.minimumInteritemSpacing = 5
        
        super.init(collectionViewLayout: layout)
        
        collectionView.backgroundColor = .white
        collectionView.register(cellType: GroupMemberCollectionViewCell.self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(dataSource?.count ?? 0, 6)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: GroupMemberCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)
        if let model = dataSource?[indexPath.row] {
            cell.avatarImageView.image = model.avatar
            cell.nameLabel.text = model.nickname
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let model = dataSource?[indexPath.row] {
            didSelect?(model)
        }
    }
}

class GroupMemberListBottomView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.height.equalTo(44)
            make.centerX.equalToSuperview()
        }
        
        let label = UILabel()
        label.textColor = UIColor("#171F24")
        label.text = NSLocalizedString("All Members", comment: "")
        label.font = UIFont.systemFont(ofSize: 16)
        label.sizeToFit()
        containerView.addSubview(label)
        
        let arrowImageView = UIImageView()
        arrowImageView.image = UIImage(named: "RightIndicator")
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tintColor = .tokFootnote
        containerView.addSubview(arrowImageView)
        
        containerView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        containerView.addSubview(arrowImageView)
        arrowImageView.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 15, height: 15))
            make.centerY.equalToSuperview()
            make.left.equalTo(label.snp.right).offset(8)
            make.right.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
