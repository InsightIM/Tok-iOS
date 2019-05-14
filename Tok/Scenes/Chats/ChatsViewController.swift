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

class ChatsViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    private let submanagerObjects: OCTSubmanagerObjects
    
    fileprivate let dateFormatter: DateFormatter
    fileprivate let timeFormatter: DateFormatter
    
    private(set) var chats: Results<OCTChat>!
    fileprivate var chatsToken: RLMNotificationToken?
    fileprivate let friends: Results<OCTFriend>
    fileprivate var friendsToken: RLMNotificationToken?
    
    fileprivate var updating: Bool = false
    
    lazy var addButton: UIBarButtonItem = {
        let button = UIButton(type: .system)
        button.frame = CGRect(0, 0, 30, 30)
        button.tintColor = .tokBlack
        button.setImage(UIImage(named: "BarbuttoniconAdd"), for: .normal)
        button.addTarget(self, action: #selector(ChatsViewController.addButtonClick(sender:)), for: .touchUpInside)
        let item = UIBarButtonItem(customView: button)
        return item
    }()
    
    lazy var emptyView = ChatEmptyView()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
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
        title = NSLocalizedString("Chats", comment: "")
        largeTitleDisplay = true
        
        navigationItem.rightBarButtonItem = addButton
        
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
                self.presentInvite()
            })
            .disposed(by: disposeBag)
        
        emptyView.addButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                let vc = AddFriendViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: disposeBag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let string = UIPasteboard.general.string,
            let address = UserService.shared.matchNewFriendCommand(text: string) {
            UIPasteboard.general.string = ""
            
            let message = String(format: NSLocalizedString("New Friend's Tok ID is %@", comment: ""), address)
            let alert = UIAlertController(title: NSLocalizedString("Add Contact", comment: ""), message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in
                let vc = AddFriendViewController()
                vc.textView.text = address
                self?.navigationController?.pushViewController(vc, animated: true)
            }
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
            
            alert.addAction(okAction)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
        }
    }
    
    override init() {
        self.submanagerObjects = UserService.shared.toxMananger!.objects
        chats = submanagerObjects.chats().sortedResultsUsingProperty("lastActivityDateInterval", ascending: false)
        
        self.friends = submanagerObjects.friends()
        
        self.dateFormatter = DateFormatter(type: .relativeDate)
        self.timeFormatter = DateFormatter(type: .time)
        
        super.init()
        
        addNotificationBlocks()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        chatsToken?.invalidate()
        friendsToken?.invalidate()
    }
    
    func setupEmptyView(isShow: Bool) {
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
        PopupMenu.showRelyOnView(view: sender as UIView, titles: [NSLocalizedString("Add Contacts", comment: ""), NSLocalizedString("Scan", comment: ""), NSLocalizedString("My Tok ID", comment: "")], icons: ["BarbuttoniconAddfriends", "BarbuttoniconScan", "BarbuttoniconID"], menuWidth: 180, didSelectRow: { [unowned self] (index, _, _) in
            switch index {
            case 0:
                let vc = AddFriendViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            case 1:
                let vc = QRScannerController(fromAddVC: false)
                self.navigationController?.pushViewController(vc, animated: true)
            case 2:
                let vc = QRViewerController(text: UserService.shared.toxMananger!.user.userAddress)
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
}

extension ChatsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ChatsCell = tableView.dequeueReusableCell(for: indexPath)
        let chat = chats[indexPath.row]
        
        cell.bindViewModel(chat: chat, timeFormatter: timeFormatter, dateFormatter: dateFormatter)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let chat = chats[indexPath.row]
        let vc = ConversationViewController(chat: chat)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: NSLocalizedString("Delete", comment: "")) { [unowned self] (_, index) in
            
            let title = NSLocalizedString("Delete this chat and message history?", comment: "")
            let deleteAction: AlertViewManager.Action = { [unowned self] in
                let chat = self.chats[indexPath.row]
                UserService.shared.toxMananger!.chats.removeAllMessages(in: chat, removeChat: true)
                return ()
            }
            
            AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)])
        }
        
        let markAsReadTitle = NSLocalizedString("Mark as Read", comment: "")
        let markAsReadAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: markAsReadTitle) { [unowned self] (_, indexPath) in
            let chat = self.chats[indexPath.row]
            UserService.shared.toxMananger!.chats.markChatMessages(asRead: chat)
        }
        
        deleteAction.backgroundColor = .tokNotice
        return [deleteAction, markAsReadAction]
    }
}

private extension ChatsViewController {
    func addNotificationBlocks() {
        chatsToken = chats.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                self.setupEmptyView(isShow: self.chats.count == 0)
                break
            case .update(let results, let deletions, let insertions, let modifications):
                guard let results = results else { return }
                
                if self.updating {
                    DispatchQueue.global(qos: .userInitiated).async {
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                            self.updating = false
                        }
                    }
                } else {
                    self.updating = true
                    
                    let deletes = deletions.map { IndexPath(row: $0, section: 0) }
                    let inserts = insertions.map { IndexPath(row: $0, section: 0) }
                    let updates = modifications.map { IndexPath(row: $0, section: 0) }
                    
                    UIView.performWithoutAnimation {
                        self.tableView.beginUpdates()
                        self.tableView.deleteRows(at: deletes, with: .none)
                        self.tableView.insertRows(at: inserts, with: .none)
                        self.tableView.reloadRows(at: updates, with: .none)
                        self.tableView.endUpdates()
                        
                        self.updating = false
                    }
                }
                
                self.setupEmptyView(isShow: results.count == 0)
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
                
                for index in modifications {
                    let friend = friends[index]
                    
                    let pathsToUpdate = self.tableView.indexPathsForVisibleRows?.filter {
                        let chat = self.chats[$0.row]
                        guard let chatFriends = chat.friends,
                            let chatFriend = chatFriends.firstObject() as? OCTFriend,
                            chatFriend.publicKey == friend.publicKey else {
                                return false
                        }
                        return true
                    }
                    
                    if let paths = pathsToUpdate {
                        self.tableView.reloadRows(at: paths, with: .none)
                    }
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    func dateTextFromDate(_ date: Date) -> String {
        let isToday = (Calendar.current as NSCalendar).compare(Date(), to: date, toUnitGranularity: .day) == .orderedSame
        return isToday ? timeFormatter.string(from: date) : dateFormatter.string(from: date)
    }
}

extension OCTChat {
    
    func lastMessageAbstract() -> OCTMessageAbstract? {
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "chatUniqueIdentifier == %@", uniqueIdentifier),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "senderUniqueIdentifier != nil AND messageText != nil AND messageText.status == 1"),
                NSPredicate(format: "senderUniqueIdentifier != nil AND messageText == nil"),
                NSPredicate(format: "senderUniqueIdentifier == nil")
                ]),
            ])
        
        let messageAbstracts = UserService.shared.toxMananger!.objects.messages(predicate: predicate).sortedResultsUsingProperty("dateInterval", ascending: false)
        return messageAbstracts.firstObject
    }
    
    func lastMessageText() -> (Bool, String?, String) {
        if let enteredText = enteredText, enteredText.isNotEmpty {
            return (true, nil, enteredText)
        }
        
        let hasDraft = false
        guard let message = lastMessageAbstract() else {
            return (hasDraft, nil, "")
        }
        
        if let text = message.messageText {
            let content = text.text ?? ""
            return (hasDraft, nil, content)
        }
        
        if let file = message.messageFile {
            let imageName = file.imageNameFromType()
            var text = ""
            switch imageName {
            case "MessageFile": text = file.fileName ?? "[File]"
            case "MessagePhoto": text = "[Photo]"
            case "MessageAudio": text = "[Audio]"
            case "MessageVideo": text = "[Video]"
            default: text = file.fileName ?? "[File]"
            }
            return (hasDraft, imageName, text)
        } else if let _ = message.messageCall {
            return message.isOutgoing() ? (hasDraft, nil, "[Outgoing Call]") : (hasDraft, nil, "[Incoming Call]")
        }
        
        return (hasDraft, nil, "")
    }
    
    func unreadMessagesCount() -> Int {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "senderUniqueIdentifier != nil AND chatUniqueIdentifier == %@ AND readed == NO", uniqueIdentifier),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "senderUniqueIdentifier != nil AND messageText != nil AND messageText.status == 1"),
                NSPredicate(format: "senderUniqueIdentifier != nil AND messageText == nil"),
                ]),
            ])
        
        let messageAbstracts = UserService.shared.toxMananger!.objects.messages(predicate: predicate)
        return messageAbstracts.count
    }
}
