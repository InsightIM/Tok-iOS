//
//  ChatsCell.swift
//  Tok
//
//  Created by Bryce on 2018/6/23.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import Reusable
import RxSwift
import RxCocoa

extension UITableViewCell: Reusable {}

class ChatsCell: UITableViewCell {
    
    private var disposeBag = DisposeBag()
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.black
        return label
    }()
    
    lazy var muteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatMute")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var topStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, verifiedImageView, muteImageView])
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var lastMessageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor("#B5B5BB")
        return label
    }()
    
    lazy var bottomStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, lastMessageLabel])
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = .tokFootnote
        return label
    }()
    
    lazy var userStatusView: UserStatusView = {
        let view = UserStatusView()
        view.isHidden = true
        return view
    }()
    
    lazy var badgeView: BadgeView = {
        let badge =  BadgeView()
        badge.insets = CGSize(width: 3, height: 3)
        badge.font = UIFont.systemFont(ofSize: 12)
        badge.textColor = UIColor.white
        badge.badgeColor = UIColor.tokNotice
        badge.isHidden = true
        return badge
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(50).priorityRequired()
            make.height.equalTo(50)
        }
        
        contentView.addSubview(userStatusView)
        userStatusView.snp.makeConstraints { (make) in
            make.size.equalTo(UserStatusView.Constants.DefaultSize)
            make.bottom.right.equalTo(avatarImageView).offset(UserStatusView.Constants.DefaultSize / 2)
        }
        
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(topStackView)
        topStackView.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.top.equalTo(avatarImageView)
            make.height.equalTo(25)
        }
        
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { (make) in
            make.trailing.equalTo(-20)
            make.centerY.equalTo(topStackView)
            make.leading.greaterThanOrEqualTo(topStackView.snp.trailing).offset(8).priorityHigh()
        }
        
        lastMessageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(bottomStackView)
        bottomStackView.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.top.equalTo(nameLabel.snp.bottom).offset(5)
        }
        
        badgeView.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(badgeView)
        badgeView.snp.makeConstraints { (make) in
            make.leading.greaterThanOrEqualTo(bottomStackView.snp.trailing).offset(8).priorityHigh()
            make.trailing.equalTo(-20)
            make.centerY.equalTo(bottomStackView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var viewModel: ChatsViewModel!
    
    func bindViewModel(_ viewModel: ChatsViewModel) {
        self.viewModel = viewModel
        
        viewModel.avatar.asDriver().drive(avatarImageView.rx.image).disposed(by: disposeBag)
        
        userStatusView.isHidden = viewModel.userStatusViewHidden
        nameLabel.text = viewModel.name
        userStatusView.userStatus = viewModel.userStatus
        
        viewModel.lastMessageText
            .asDriver()
            .drive(onNext: { [weak self] (hasDraft, imageName, lastMessage) in
                guard let self = self else { return }
                self.iconImageView.isHidden = imageName == nil
                if let imageName = imageName {
                    self.iconImageView.image = UIImage(named: imageName)
                } else {
                    self.iconImageView.image = nil
                }
                
                if lastMessage.isEmpty {
                    self.lastMessageLabel.text = NSLocalizedString("Start Chatting!", comment: "")
                } else {
                    if hasDraft {
                        let attributedText = NSMutableAttributedString(string: "[\(NSLocalizedString("Draft", comment: ""))]", attributes: [.foregroundColor : UIColor("#A72A21")])
                        attributedText.append(NSAttributedString(string: lastMessage))
                        self.lastMessageLabel.attributedText = attributedText
                    } else {
                        self.lastMessageLabel.text = lastMessage
                    }
                }
            })
            .disposed(by: disposeBag)
        
        timeLabel.text = viewModel.lastActivityDate
        muteImageView.isHidden = !viewModel.isMuted
        verifiedImageView.isHidden = !viewModel.verified
        
        badgeView.badgeColor = viewModel.isMuted ? .tokDarkGray : .tokNotice
        viewModel.unreadCount.asDriver().drive(badgeView.rx.text).disposed(by: disposeBag)
        viewModel.unreadCount.map { $0 == nil }.asDriver(onErrorJustReturn: true).drive(badgeView.rx.isHidden).disposed(by: disposeBag)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}
