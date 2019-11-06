//
//  ConversationTitleView.swift
//  Tok
//
//  Created by Bryce on 2018/12/16.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class ConversationTitleView: UIView {
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, verifiedImageView, muteImageView])
        stackView.alignment = .center
        stackView.spacing = 3
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = UIColor.tokBlack
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        
        titleLabel.textAlignment = .center
        titleLabel.minimumScaleFactor = 15.0 / 17.0
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.sizeToFit()
        
        return titleLabel
    }()
    
    lazy var muteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatMute")
        return imageView
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.textColor = .tokDarkGray
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textAlignment = .center
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.sizeToFit()
        
        return subtitleLabel
    }()
    
    lazy var userStatusView: UserStatusView = {
        let view = UserStatusView()
        return view
    }()
    
    private let chat: OCTChat
    private let manager: OCTManager
    private let database: Database
    private var friendToken: RLMNotificationToken?
    private var chatToken: RLMNotificationToken?
    
    init(chat: OCTChat, messageService: MessageService) {
        self.chat = chat
        self.manager = messageService.tokManager.toxManager
        self.database = messageService.database
        super.init(frame: .zero)
        setupViews()
        
        bindStatus()
        addFriendNotification()
        addChatNotification()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        friendToken?.invalidate()
        chatToken?.invalidate()
    }
    
    func update(title: String, subtitle: String, userStatus: UserStatus, muted: Bool, verified: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        userStatusView.userStatus = userStatus
        muteImageView.isHidden = !muted
        verifiedImageView.isHidden = !verified
    }
    
    private func setupViews() {
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        addSubview(stackView)
        addSubview(subtitleLabel)
        addSubview(userStatusView)
        
        stackView.snp.makeConstraints { (make) in
            make.top.equalTo(6)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.height.equalTo(20)
        }
        
        subtitleLabel.snp.makeConstraints { (make) in
            make.top.equalTo(stackView.snp.bottom)
            make.centerX.equalToSuperview()
        }
        
        userStatusView.snp.makeConstraints { (make) in
            make.trailing.equalTo(subtitleLabel.snp.leading).offset(-3)
            make.size.equalTo(CGSize(width: 6, height: 6))
            make.centerY.equalTo(subtitleLabel)
        }
    }
    
    private func addFriendNotification() {
        var predicate: NSPredicate
        if chat.isGroup {
            predicate = NSPredicate(format: "publicKey == %@", BotService.shared.groupBot.publicKey)
        } else {
            guard let friend = chat.friends?.firstObject() as? OCTFriend else {
                return
            }
            
            predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "publicKey == %@", friend.publicKey),
                NSPredicate(format: "publicKey == %@", BotService.shared.offlineBot.publicKey),
                ])
        }
        
        let results = manager.objects.friends(predicate: predicate)
        
        friendToken = results.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update:
                self.bindStatus()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func addChatNotification() {
        let predicate = NSPredicate(format: "uniqueIdentifier == %@", chat.uniqueIdentifier)
        let results = manager.objects.chats(predicate: predicate)
        
        chatToken = results.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update(_, _, _, let updates):
                guard updates.count > 0 else { return }
                self.bindStatus()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func bindStatus() {
        guard chat.isInvalidated == false else { return }
        if chat.isGroup {
            bindGroupStatus()
        } else {
            bindFriendStatus()
        }
    }
    
    private func bindGroupStatus() {
        guard let bot = database.findFriend(withPublicKey: BotService.shared.groupBot.publicKey) else {
            return
        }
        
        let verified = chat.isVerified
        let title = chat.title ?? "Group \(chat.groupNumber)"
        let groupType = chat.groupType == 1 ? " · \(NSLocalizedString("Public Group", comment: ""))" : ""
        let members =  "\(chat.groupMemebersCount) \(NSLocalizedString("Members", comment: ""))"
        
        let subTitle = bot.isConnected
            ? members + groupType
            : NSLocalizedString("Secure connecting...", comment: "")
        
        let status: UserStatus = bot.isConnected ? .online : .offline
        update(title: title, subtitle: subTitle, userStatus: status, muted: chat.isMute, verified: verified)
    }
    
    private func bindFriendStatus() {
        guard let friend = chat.friends?.firstObject() as? OCTFriend else {
            return
        }

        let verified = chat.isVerified
        if friend.isConnected == false, let bot = database.findFriend(withPublicKey: BotService.shared.offlineBot.publicKey) {
            let statusString = bot.isConnected
                ? NSLocalizedString("Away", comment: "")
                : NSLocalizedString("Peer-to-peer connecting...", comment: "")
            let botStatus: UserStatus = bot.isConnected ? .away : .offline
            update(title: friend.nickname, subtitle: statusString, userStatus: botStatus, muted: false, verified: verified)
        } else {
            let status: UserStatus = friend.isConnected ? .online : .offline
            update(title: friend.nickname, subtitle: status.toString(), userStatus: status, muted: false, verified: verified)
        }
    }
}
