//
//  GroupDetailViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2018/12/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Action

class GroupTitleCell: UITableViewCell {
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .tokTitle4
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, verifiedImageView])
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.lessThanOrEqualTo(-10)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(44).priorityHigh()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GroupDetailViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    
    private let isOwner: Bool
    private let chat: OCTChat
    private let messageService: MessageService
    private let manager: OCTManager
    private let messageSender: MessagesSender
    private var peers: [Peer] = []
    private var chatToken: RLMNotificationToken?
    private let isPublicGroup: Bool
    
    init(chat: OCTChat, messageService: MessageService) {
        self.chat = chat
        self.isOwner = chat.ownerPublicKey == messageService.tokManager.tox.publicKey
        self.isPublicGroup = chat.groupType == 1
        self.messageService = messageService
        self.manager = messageService.tokManager.toxManager
        self.messageSender = messageService.messageSender
        
        let cachePeers: [OCTPeer] = manager.objects.peers(predicate: NSPredicate(format: "groupNumber == %lld", chat.groupNumber)).toList()
        peers = cachePeers.map { model in
            let avatar = AvatarManager.shared.image(bySenderId: model.publicKey ?? "?", messageService: messageService)
            return Peer(nickname: model.nickname ?? "?", publicKey: model.publicKey ?? "", confirmFlag: 0, avatar: avatar)
        }
        super.init()
        
        addChatNotification()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 20
        tableView.sectionFooterHeight = 0.01
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 15))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellType: GroupTitleCell.self)
        tableView.register(cellType: GroupInfoCell.self)
        tableView.register(cellType: SwitchCell.self)
        tableView.register(cellType: GroupMemberListCell.self)
        tableView.register(cellType: SettingsCell.self)
        
        return tableView
    }()
    
    lazy var removeButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Delete and Leave", comment: ""), color: .tokNotice)
        return button
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 90))
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Group Info", comment: "")
        
        tableView.tableFooterView = footerView
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let title = isOwner ? NSLocalizedString("Dissolve this group", comment: "") : NSLocalizedString("Delete and Leave", comment: "")
        removeButton.fcStyle(title: title, color: .tokNotice)
        footerView.addSubview(removeButton)
        removeButton.snp.makeConstraints({ (make) in
            make.top.equalTo(40).priority(.high)
            make.left.equalTo(16).priority(.high)
            make.right.equalTo(-16).priority(.high)
            make.height.equalTo(50)
        })
        
        removeButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                let title = self.isOwner
                    ? NSLocalizedString("Are you sure you want to dissolve this group?", comment: "")
                    : String(format: NSLocalizedString("Are you sure you want to leave %@?", comment: ""), self.chat.title ?? NSLocalizedString("this group", comment: ""))
                
                let okAction: AlertViewManager.Action = { [unowned self] in
                    if self.manager.chats.leaveGroup(withGroupNumber: self.chat.groupNumber) {
                        self.messageService.database.removeAllMessages(inChat: self.chat.uniqueIdentifier, removeChat: true)
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                }
                
                AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("OK", comment: ""), .destructive, okAction)])
            })
            .disposed(by: disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadGroupMembers()
    }
    
    deinit {
        chatToken?.invalidate()
    }
    
    func loadGroupMembers() {
        messageService.getPeerList(groupId: UInt64(chat.groupNumber), page: 0)
            .subscribe(onNext: { [weak self] result in
                guard self?.chat.isInvalidated == false else { return }
                self?.peers = result.0
                UIView.performWithoutAnimation {
                    self?.tableView.reloadData()
                }
            })
            .disposed(by: disposeBag)
    }
    
    func addChatNotification() {
        guard chat.isGroup else {
            return
        }
        
        let result = manager.objects.chats(predicate: NSPredicate(format: "uniqueIdentifier == %@", chat.uniqueIdentifier))
        
        chatToken = result.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            if self.chat.isInvalidated {
                return
            }
            switch change {
            case .initial:
                break
            case .update(_, _, _, let modifications):
                guard modifications.count > 0 else { return }
                UIView.performWithoutAnimation {
                    self.tableView.reloadData()
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}

extension GroupDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return isPublicGroup ? 4 : 3
        case 1: return 1
        case 2: return 2
        case 3: return 1
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let cell: GroupTitleCell = tableView.dequeueReusableCell(for: indexPath)
                cell.accessoryType = isOwner ? .disclosureIndicator : .none
                cell.nameLabel.text = chat.title ?? "Group \(chat.groupNumber)"
                cell.verifiedImageView.isHidden = !chat.isVerified
                return cell
            }
            
            let cell: GroupInfoCell = tableView.dequeueReusableCell(for: indexPath)
            cell.textLabel?.textColor = .tokTitle4
            cell.detailTextLabel?.textColor = .tokFootnote
            
            cell.textLabel?.text = nil
            cell.detailTextLabel?.text = nil
            
            switch indexPath.row {
            case 1:
                cell.accessoryType = isOwner ? .disclosureIndicator : .none
                var desc = isOwner ? NSLocalizedString("Description(Option)", comment: "") : NSLocalizedString("No Description", comment: "")
                if let groupDescription = chat.groupDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
                    groupDescription.isNotEmpty {
                    desc = groupDescription
                }
                cell.textLabel?.text = desc
                cell.textLabel?.textColor = UIColor.tokFootnote
            case 2:
                cell.textLabel?.text = NSLocalizedString("Group Type", comment: "")
                cell.detailTextLabel?.text = chat.groupType == 0 ? NSLocalizedString("Private", comment: "") : NSLocalizedString("Public", comment: "")
                cell.accessoryType = .disclosureIndicator
            default:
                cell.textLabel?.text = NSLocalizedString("Share Group", comment: "")
                cell.detailTextLabel?.text = chat.groupId
                cell.detailTextLabel?.textColor = .tokLink
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        case 1:
            let cell: GroupMemberListCell = tableView.dequeueReusableCell(for: indexPath)
            cell.topView.textLabel.text = NSLocalizedString("Group Members", comment: "") + " (\(chat.groupMemebersCount))"
            cell.middleView.dataSource = peers
            cell.middleView.didSelect = { [unowned self] peer in
                guard peer.publicKey != self.messageService.tokManager.tox.publicKey else {
                    let vc = ProfileViewController(messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                    return
                }
                let vc = FriendViewController(messageService: self.messageService, publicKey: peer.publicKey, chat: self.chat)
                self.navigationController?.pushViewController(vc, animated: true)
            }
            
            let editTitle = isOwner ? NSLocalizedString("Add/Remove", comment: "") : NSLocalizedString("Add_Group_Members", comment: "")
            cell.topView.editButton.setTitle(editTitle, for: .normal)
            cell.topView.editButton.rx.action = CocoaAction { [unowned self] in
                if self.isOwner {
                    let action: (EditGroupViewController.EditGroupAction) -> Void = { [unowned self] editAction in
                        let vc = EditGroupViewController(chat: self.chat, action: editAction, messageService: self.messageService)
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                    AlertViewManager.showActionSheet(with:
                        [(NSLocalizedString("Add Members", comment: ""), .default, {
                            action(.add)
                        }),
                         (NSLocalizedString("Remove Members", comment: ""), .destructive, {
                            action(.remove)
                         })]
                    )
                } else {
                    let vc = EditGroupViewController(chat: self.chat, action: .add, messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                return .empty()
            }
            
            let tap = UITapGestureRecognizer()
            tap.rx.event
                .subscribe(onNext: { [unowned self] _ in
                    let vc = GroupMembersViewController(chat: self.chat, messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                })
                .disposed(by: cell.disposeBag)
            cell.bottomView.addGestureRecognizer(tap)
            return cell
        case 2:
            switch indexPath.row {
            case 0:
                let cell: SwitchCell = tableView.dequeueReusableCell(for: indexPath)
                cell.nameLabel.text = NSLocalizedString("Mute Notifications", comment: "")
                cell.switchButton.isOn = chat.isMute
                cell.switchButton.rx.isOn
                    .skip(1)
                    .distinctUntilChanged()
                    .subscribe(onNext: { [unowned self] isOn in
                        guard let chatToken = self.chatToken else { return }
                        self.manager.chats.setIsMute(isOn, in: self.chat, withoutNotifying: [chatToken])
                    })
                    .disposed(by: cell.disposeBag)
                return cell
            default:
                let cell: SettingsCell = tableView.dequeueReusableCell(for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Clear History", comment: "")
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        default:
            let cell: SettingsCell = tableView.dequeueReusableCell(for: indexPath)
            cell.textLabel?.text = NSLocalizedString("Report", comment: "")
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 44
        case 1: return 123 + 44
        case 2: return 44
        default: return 44
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                guard isOwner else { return }
                let vc = ChangeGroupNameViewController(chat: chat)
                navigationController?.pushViewController(vc, animated: true)
            case 1:
                guard isOwner else { return }
                let vc = ChangeGroupDescViewController(chat: chat, toxManager: manager)
                let navigationController = UINavigationController(rootViewController: vc)
                present(navigationController, animated: true, completion: nil)
            case 2:
                let title = NSLocalizedString("· Private groups only can be joined if you were invited and can not be found in search.\n· Public groups can be found in search and everyone can join.", comment: "")
                AlertViewManager.showMessageSheet(with: title, cancelTitle: NSLocalizedString("OK", comment: ""))
            case 3:
                shareGroupID()
            default: return
            }
        } else if indexPath.section == 2, indexPath.row == 1 { // clear group messages
            let title = NSLocalizedString("Are you sure you want to clear history?", comment: "")
            let delete = NSLocalizedString("Delete", comment: "")
            let deleteAction: AlertViewManager.Action = { [weak self] in
                guard let self = self else { return }
                self.messageService.database.removeAllMessages(inChat: self.chat.uniqueIdentifier, removeChat: false)
            }
            
            AlertViewManager.showMessageSheet(with: title, actions: [(delete, .destructive, deleteAction)])
        } else if indexPath.section == 3, indexPath.row == 0 {
            let actions = ["Spam", "Violence", "Pornography", "Child Abuse", "Copyright", "Other"].map { title -> (String, UIAlertAction.Style, AlertViewManager.Action?) in
                let action: AlertViewManager.Action = { [weak self] in
                    guard let self = self else { return }
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Thank you! Your report will be reviewed by Tok team very soon", comment: ""), in: self.view)
                }
                return (title, UIAlertAction.Style.default, action)
            }
            AlertViewManager.showActionSheet(with: actions)
        }
    }
}

extension GroupDetailViewController {
    func shareGroupID() {
        let title = chat.title ?? "Group \(chat.groupNumber)"
        let groupId = chat.groupId ?? ""
        
        let localizedString1 = NSLocalizedString("Copy this paragraph and open Tok to join: %@ %@, download Tok on %@ -- the most secure messenger", comment: "")
        let localizedString2 = NSLocalizedString("%@\nClick to join the group", comment: "")
        let shareText1 = String(format: localizedString1, title, groupId, officalLink)
        let shareText2 = String(format: localizedString2, "\(title) \(groupId)")

        AlertViewManager.showMessageSheet(with: "\(title) \(groupId)", actions: [
            (NSLocalizedString("Share to Friends", comment: ""), .default, { [unowned self] in
                let items: [Any] = [shareText1]
                let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                self.present(vc, animated: true, completion: nil)
            }), (NSLocalizedString("Share to Chats", comment: ""), .default, { [unowned self] in
                let viewModel = ForwardMessageViewModel(text: shareText2, messageService: self.messageService)
                let vc = ForwardChatViewController(viewModel: viewModel)
                let nav = UINavigationController(rootViewController: vc)
                self.present(nav, animated: true, completion: nil)
            }), (NSLocalizedString("Copy", comment: ""), .default, {
                UIPasteboard.general.string = shareText2
            })
            ])
    }
}
