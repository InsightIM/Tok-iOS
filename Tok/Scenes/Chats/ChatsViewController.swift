//
//  ChatsViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Action
import MobileCoreServices
import SafariServices
import DeepDiff

class ChatsViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    private let toxManager: OCTManager
    private let messageSender: MessagesSender
    
    fileprivate let dateFormatter: DateFormatter
    fileprivate let timeFormatter: DateFormatter
    
    fileprivate var chatsToken: RLMNotificationToken?
    fileprivate let friends: Results<OCTFriend>
    fileprivate var friendsToken: RLMNotificationToken?
    private var unreadMessagesToken: RLMNotificationToken?
    
    private let updatingQueue = DispatchQueue(label: "com.insight.chats.updating", qos: .userInitiated)
    
    private lazy var userDefaultsManager = UserDefaultsManager()
    private var items: [ChatsViewModel] = []
    private lazy var avatarCache = NSCache<AnyObject, UIImage>()
    
    lazy var titleView = ChatsTitleView()
    
    lazy var addButton: UIBarButtonItem = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.tintColor = .tokBlack
        button.setImage(UIImage(named: "BarbuttoniconAdd"), for: .normal)
        button.addTarget(self, action: #selector(ChatsViewController.addButtonClick(sender:)), for: .touchUpInside)
        let item = UIBarButtonItem(customView: button)
        return item
    }()
    
    lazy var groupSearchButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.tintColor = .tokBlack
        button.setImage(UIImage(named: "BarbuttonGroupSearch"), for: .normal)
        button.addTarget(self, action: #selector(ChatsViewController.didClickGroupSearch), for: .touchUpInside)
        return button
    }()
    
    lazy var networkButton: UIBarButtonItem = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.tintColor = .tokBlack
        button.setImage(UIImage(named: "BarbuttonNetwork"), for: .normal)
        button.addTarget(self, action: #selector(ChatsViewController.didClickNetwork), for: .touchUpInside)
        let item = UIBarButtonItem(customView: button)
        return item
    }()
    
    lazy var groupNewFeatureView: UIView = {
        let badge = BadgeView()
        badge.frame = CGRect(x: 22, y: 2, width: 8, height: 8)
        badge.insets = CGSize(width: 8, height: 8)
        badge.badgeColor = UIColor.tokNotice
        badge.text = ""
        return badge
    }()
    
    lazy var emptyView = ChatEmptyView()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 68
        tableView.register(cellType: ChatsCell.self)
        
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = titleView
        largeTitleDisplay = false
        
        if userDefaultsManager.newFeatureForGroupRecommend {
            groupSearchButton.addSubview(groupNewFeatureView)
        }
        let groupSearchButtonItem = UIBarButtonItem(customView: groupSearchButton)
        navigationItem.rightBarButtonItems = [addButton, groupSearchButtonItem, networkButton]
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        emptyView.linkTipButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.presentPrivacy()
            })
            .disposed(by: disposeBag)
        
        emptyView.inviteButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.presentInvite(messageService: self.messageService)
            })
            .disposed(by: disposeBag)
        
        emptyView.addButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                let vc = AddFriendViewController(messageService: self.messageService)
                self.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: disposeBag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let string = UIPasteboard.general.string {
            if let address = messageService.matchNewFriendCommand(text: string) {
                UIPasteboard.general.string = ""

                let message = String(format: NSLocalizedString("New Friend's Tok ID is %@", comment: ""), address)
                let alert = UIAlertController(title: NSLocalizedString("Add Contact", comment: ""), message: message, preferredStyle: .alert)
                let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [unowned self] _ in
                    let vc = AddFriendViewController(messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
                
                alert.addAction(okAction)
                alert.addAction(cancelAction)
                present(alert, animated: true, completion: nil)
            } else if let shareId = messageService.matchGroupShareId(text: string) {
                UIPasteboard.general.string = ""

                let title = String(format: NSLocalizedString("Do you want to view group %@", comment: ""), shareId)
                AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("View", comment: ""), .default, { [unowned self] in
                    let vc = GroupViewerViewController(groupShareId: shareId, messageService: self.messageService)
                    self.navigationController?.pushViewController(vc, animated: true)
                })])
            }
        }
    }
    
    private let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        self.toxManager = messageService.tokManager.toxManager
        self.messageSender = messageService.messageSender
        
        self.friends = messageService.database.normalFriends()
        
        self.dateFormatter = DateFormatter(type: .relativeDate)
        self.timeFormatter = DateFormatter(type: .time)
        
        super.init()
        
        updateModels(isInit: true)
        addNotificationBlocks()
        
        NotificationCenter.default.rx.notification(.UpdateChatAvatar)
            .debug("UpdateChatAvatar")
            .subscribe(onNext: { [weak self] notification in
                guard let self = self else { return }
                if let chat = notification.userInfo?["chat"] as? OCTChat,
                    let index = self.items.firstIndex(where: { $0.id == chat.uniqueIdentifier }) {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
            })
            .disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        chatsToken?.invalidate()
        friendsToken?.invalidate()
        unreadMessagesToken?.invalidate()
    }
    
    private func setupEmptyView(isShow: Bool) {
        if isShow {
            view.addSubview(emptyView)
            emptyView.snp.makeConstraints { (make) in
                make.center.equalToSuperview()
                make.left.right.equalToSuperview()
            }
        } else {
            emptyView.removeFromSuperview()
        }
    }
    
    // MARK: - Action
    
    @objc func addButtonClick(sender: UIButton) {
        PopupMenu.showRelyOnView(view: sender as UIView, titles: [NSLocalizedString("Add Contacts", comment: ""), NSLocalizedString("New Group", comment: ""), NSLocalizedString("Scan", comment: ""), NSLocalizedString("My Tok ID", comment: "")], icons: ["BarbuttoniconAddfriends", "BarbuttoniconGroup", "BarbuttoniconScan", "BarbuttoniconID"], menuWidth: 180, didSelectRow: { [unowned self] (index, _, _) in
            switch index {
            case 0:
                let vc = AddFriendViewController(messageService: self.messageService)
                self.navigationController?.pushViewController(vc, animated: true)
            case 1:
                let vc = GroupTypeViewController(messageService: self.messageService)
                self.navigationController?.pushViewController(vc, animated: true)
            case 2:
                let vc = QRScannerController(fromAddVC: false, messageService: self.messageService)
                self.navigationController?.pushViewController(vc, animated: true)
            case 3:
                let vc = QRViewerController(messageService: self.messageService)
                self.navigationController?.pushViewController(vc, animated: true)
            default:
                print("\(index)")
            }
        }) { popupMenu in
            popupMenu.itemHeight = 48
            popupMenu.backColor = UIColor("#38383E")
            popupMenu.textColor = .white
            popupMenu.separatorColor = .clear
            popupMenu.priorityDirection = .top
            popupMenu.borderWidth = 0
            popupMenu.borderColor = .clear
            popupMenu.rectCorner = []
        }
    }
    
    @objc
    func didClickGroupSearch() {
        if userDefaultsManager.newFeatureForGroupRecommend {
            groupNewFeatureView.removeFromSuperview()
            userDefaultsManager.newFeatureForGroupRecommend = false
        }
        let vc = GroupRecommendViewController(messageService: messageService)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    func didClickNetwork() {
        let vc = NetworkSettingViewController(messageService: messageService)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension ChatsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ChatsCell = tableView.dequeueReusableCell(for: indexPath)
        let viewModel = items[indexPath.row]
        
        cell.bindViewModel(viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        if let navigationController = navigationController {
            guard navigationController.topViewController == self else {
                return
            }
        }
        
        guard let chat = messageService.database.findChat(byId: items[indexPath.row].id) else {
            return
        }
        
        let vc = ConversationViewController()
        vc.dataSource = ConversationDataSource(messageService: messageService, chat: chat)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: NSLocalizedString("Delete", comment: "")) { [unowned self] (_, index) in
            
            let title = NSLocalizedString("Delete this chat and message history?", comment: "")
            let deleteAction: AlertViewManager.Action = { [unowned self] in
                self.messageService.database.removeAllMessages(inChat: self.items[indexPath.row].id, removeChat: true)
            }
            
            AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)])
        }
        
        let markAsReadTitle = NSLocalizedString("Mark as Read", comment: "")
        let markAsReadAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: markAsReadTitle) { [unowned self] (_, indexPath) in
            self.messageService.database.markMessagesAsRead(inChat: self.items[indexPath.row].id)
        }
        
        deleteAction.backgroundColor = .tokNotice
        return [deleteAction, markAsReadAction]
    }
}

private extension ChatsViewController {
    func addNotificationBlocks() {
        let chats = messageService.database.normalChats().sortedResultsUsingProperty("lastActivityDateInterval", ascending: false)
        chatsToken = chats.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let results, _, _, _):
                guard let _ = results else { return }
                self.updateModels()
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        friendsToken = friends.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let friends, _, _, let modifications):
                guard let friends = friends else {
                    break
                }
                
                var needUpdate = false
                for index in modifications {
                    let friend = friends[index]
                    
                    let pathsToUpdate = self.tableView.indexPathsForVisibleRows?.filter {
                        guard let chat = self.messageService.database.findChat(byId: self.items[$0.row].id), !chat.isGroup else {
                            return false
                        }
                        guard let chatFriend = chat.friends?.firstObject() as? OCTFriend,
                            chatFriend.publicKey == friend.publicKey else {
                                return false
                        }
                        return true
                    }
                    
                    if pathsToUpdate != nil {
                        needUpdate = true
                    }
                }
                
                if needUpdate {
                    self.updateModels()
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func findSortedChats() -> Results<OCTChat> {
        return messageService.database.normalChats().sortedResultsUsingProperty("lastActivityDateInterval", ascending: false)
    }
    
    private func updateModels(isInit: Bool = false) {
        updatingQueue.async {
            let (changes, newItems) = self.diffChats()
            performSynchronouslyOnMainThread {
                self.reloadTableView(changes: changes, newItems: newItems)
            }
        }
    }
    
    private func diffChats() -> ([Change<ChatsViewModel>], [ChatsViewModel]) {
        let chats = self.findSortedChats()
        let newItems = chats.toList().map { ChatsViewModel(chat: $0, messageService: self.messageService, timeFormatter: self.timeFormatter, dateFormatter: self.dateFormatter, cache: self.avatarCache) }
        let oldItems = self.items
        
        let changes = diff(old: oldItems, new: newItems)
        return (changes, newItems)
    }
    
    private func reloadTableView(changes: [Change<ChatsViewModel>], newItems: [ChatsViewModel]) {
        UIView.performWithoutAnimation {
            self.tableView.reload(changes: changes,
                                  insertionAnimation: .none,
                                  deletionAnimation: .none,
                                  replacementAnimation: .none,
                                  updateData: {
                                    self.items = newItems
                                    self.setupEmptyView(isShow: newItems.count == 0)
            })
        }
    }
}
