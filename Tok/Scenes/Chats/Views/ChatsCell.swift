//
//  ChatsCell.swift
//  Tok
//
//  Created by Bryce on 2018/6/23.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import Reusable

extension UITableViewCell: Reusable {}

class ChatsCell: UITableViewCell {
    
    lazy var avatarImageView: AvatarImageView = {
        let imageView = AvatarImageView()
        imageView.cornerRadius = AvatarConstants.CornerRadius
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
        return imageView
    }()
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var bottomStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, lastMessageLabel])
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    lazy var lastMessageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor("#B5B5BB")
        return label
    }()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = .tokFootnote
        return label
    }()
    
    lazy var userStatusView: UserStatusView = {
        let view = UserStatusView()
        return view
    }()
    
    lazy var badgeView: BadgeView = {
        let badge =  BadgeView()
        badge.insets = CGSize(width: 3, height: 3)
        badge.font = UIFont.systemFont(ofSize: 12)
        badge.textColor = UIColor.white
        badge.badgeColor = UIColor.tokNotice
        return badge
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.left.equalTo(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 50, height: 50))
        }
        
        contentView.addSubview(userStatusView)
        userStatusView.snp.makeConstraints { (make) in
            make.size.equalTo(UserStatusView.Constants.DefaultSize)
            make.bottom.right.equalTo(avatarImageView).offset(UserStatusView.Constants.DefaultSize / 2)
        }
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(10)
            make.top.equalTo(avatarImageView)
            make.height.equalTo(25)
        }
        
        muteImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(muteImageView)
        muteImageView.snp.makeConstraints { (make) in
            make.left.equalTo(nameLabel.snp.right).offset(10)
            make.centerY.equalTo(nameLabel)
            make.size.equalTo(12)
        }
        
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { (make) in
            make.right.equalTo(-10)
            make.centerY.equalTo(nameLabel)
            make.left.greaterThanOrEqualTo(muteImageView.snp.right).offset(10)
        }
        
        contentView.addSubview(bottomStackView)
        bottomStackView.snp.makeConstraints { (make) in
            make.left.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(5)
            make.right.lessThanOrEqualTo(-40)
        }
        
//        contentView.addSubview(lastMessageLabel)
//        lastMessageLabel.snp.makeConstraints { (make) in
//            make.left.equalTo(nameLabel)
//            make.top.equalTo(nameLabel.snp.bottom).offset(5)
//            make.right.equalTo(-40)
//        }
        
        contentView.addSubview(badgeView)
        badgeView.snp.makeConstraints { (make) in
            make.right.equalTo(-10)
            make.centerY.equalTo(lastMessageLabel)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindViewModel(chat: OCTChat, timeFormatter: DateFormatter, dateFormatter: DateFormatter) {
        
        self.chat = chat
        addNotificationBlocks(chat: chat)
        
        if chat.isGroup {
            avatarImageView.setGroupImage(avatar: AvatarManager.shared.groupAvatar(for: chat))
            userStatusView.isHidden = true
            nameLabel.text = chat.title ?? "Group \(chat.groupNumber)"
        } else if let friend = chat.friends?.lastObject() as? OCTFriend {
            avatarImageView.setFriendImage(friend: friend)
            userStatusView.isHidden = false
            userStatusView.userStatus = UserStatus(connectionStatus: friend.connectionStatus, userStatus: friend.status)
            nameLabel.text = friend.nickname
        }
        
        let (hasDraft, imageName, lastMessage) = chat.lastMessageText()
        iconImageView.isHidden = imageName == nil
        if let imageName = imageName {
            iconImageView.image = UIImage(named: imageName)
        } else {
            iconImageView.image = nil
        }
        
        if lastMessage.isEmpty {
            lastMessageLabel.text = NSLocalizedString("Start Chatting!", comment: "")
        } else {
            if hasDraft {
                let attributedText = NSMutableAttributedString(string: "[\(NSLocalizedString("Draft", comment: ""))]", attributes: [.foregroundColor : UIColor("#A72A21")])
                attributedText.append(NSAttributedString(string: lastMessage))
                lastMessageLabel.attributedText = attributedText
            } else {
                lastMessageLabel.text = lastMessage
            }
        }
        if let date = chat.lastActivityDate() {
            let isToday = (Calendar.current as NSCalendar).compare(Date(), to: date, toUnitGranularity: .day) == .orderedSame
            let time = isToday ? timeFormatter.string(from: date) : dateFormatter.string(from: date)
            timeLabel.text = time
        }
        
        muteImageView.isHidden = chat.isMute == false
        
        updateUnreadBadge()
    }
    
    private func updateUnreadBadge() {
        guard let chat = chat else {
            return
        }
        let unreadCount = chat.unreadMessagesCount()
        badgeView.isHidden = (unreadCount == 0)
        if chat.isMute {
            badgeView.text = ""
        } else {
            badgeView.text = "\(unreadCount)"
        }
    }
    
    var chat: OCTChat?
    fileprivate var unreadMessagesToken: RLMNotificationToken?
    fileprivate var unreadMessages: Results<OCTMessageAbstract>?
    
    func addNotificationBlocks(chat: OCTChat) {
        let predicate = NSPredicate(format: "senderUniqueIdentifier != nil AND chatUniqueIdentifier == %@ AND readed == NO", chat.uniqueIdentifier)
        unreadMessages = UserService.shared.toxMananger!.objects.messages(predicate: predicate)
        unreadMessagesToken = unreadMessages?.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(_, _, _, _):
                self.updateUnreadBadge()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        unreadMessagesToken?.invalidate()
        unreadMessages = nil
    }
}
