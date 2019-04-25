//
//  ContactsViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/27.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import Action

struct ContactItemModel {
    var image: UIImage?
    var title: String
    var caption: String?
    var friend: OCTFriend?
    var action: Action<OCTFriend?, Void>
}

class ContactsViewController: BaseViewController {

    private weak var submanagerObjects: OCTSubmanagerObjects!
    private weak var submanagerFriends: OCTSubmanagerFriends!
    
    fileprivate let friends: Results<OCTFriend>
    fileprivate let requests: Results<OCTFriendRequest>
    fileprivate var friendsToken: RLMNotificationToken?
    fileprivate var requestsToken: RLMNotificationToken?
    
    fileprivate let dateFormatter: DateFormatter
    fileprivate let timeFormatter: DateFormatter
    
    fileprivate let avatarManager = AvatarManager()
        
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.separatorColor = .tokLine
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.estimatedRowHeight = 64
        tableView.register(cellType: ContractMenuCell.self)
        tableView.register(cellType: ContractDetailCell.self)
        
        tableView.sectionIndexColor = UIColor("#555567")
        tableView.sectionIndexBackgroundColor = UIColor.clear
        
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    lazy var addButton: UIBarButtonItem = {
        let button = UIButton(type: .system)
        button.frame = CGRect(0, 0, 25, 25)
        button.tintColor = .tokBlack
        button.setImage(UIImage(named: "BarButtonAddFriend"), for: .normal)
        button.addTarget(self, action: #selector(ContactsViewController.addButtonClick(sender:)), for: .touchUpInside)
        let item = UIBarButtonItem(customView: button)
        return item
    }()
    
    let requestCount = BehaviorRelay(value: 0)
    
    override init() {
        self.submanagerObjects = UserService.shared.toxMananger!.objects
        self.submanagerFriends = UserService.shared.toxMananger!.friends
        self.friends = submanagerObjects.friends()
        self.requests = submanagerObjects.friendRequests()
        
        self.dateFormatter = DateFormatter(type: .relativeDate)
        self.timeFormatter = DateFormatter(type: .time)
        
        super.init()
        
        requestCount.accept(requests.count)
        addNotificationBlocks()
        
        bindData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        friendsToken?.invalidate()
        requestsToken?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Contacts", comment: "")
        largeTitleDisplay = true
        
        navigationItem.rightBarButtonItem = addButton
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    fileprivate var sectionTitles = [String]()
    fileprivate var models = [String: [ContactItemModel]]()
    
    private func setupTopMenus() -> [ContactItemModel] {
        var menus = [
            ContactItemModel(image: UIImage(named: "MenuFriendRequest"), title: NSLocalizedString("New Friend Request", comment: ""), caption: nil, friend: nil, action: Action { [unowned self] _ -> Observable<Void> in
                let vc = InvitationsViewController()
                self.navigationController?.pushViewController(vc, animated: true)
                return .empty()
            }),
            ContactItemModel(image: UIImage(named: "MenuInvitations"), title: NSLocalizedString("Invite Friend", comment: ""), caption: nil, friend: nil, action: Action { [unowned self] _  -> Observable<Void> in
                self.presentInvite()
                return .empty()
            })
        ]
        
        let findFriendBot = FindFriendBotModel()
        if findFriendBot.beAdded == false {
            let item = ContactItemModel(image: UIImage(named: "FindFriendBotIcon"), title: NSLocalizedString("FindFriendBot", comment: ""), caption: nil, friend: nil, action: Action { [unowned self] _ -> Observable<Void> in
                let vc = BotInfoViewController(bot: findFriendBot)
                self.navigationController?.pushViewController(vc, animated: true)
                return .empty()
            })
            
            menus.append(item)
        }
        
        if OfflineBotModel().beAdded == false {
            let item = ContactItemModel(image: UIImage(named: "OfflineBotIcon"), title: NSLocalizedString("OfflineMessageBot", comment: ""), caption: nil, friend: nil, action: Action { [unowned self] _ -> Observable<Void> in
                let vc = BotIntroViewController()
                self.navigationController?.pushViewController(vc, animated: true)
                return .empty()
            })
            
            menus.append(item)
        }
        
        return menus
    }
    
    private func bindData() {
        let items: [OCTFriend] = friends.toList()
        
        let action: Action<OCTFriend?, Void> = Action { [unowned self] friend -> Observable<Void> in
            guard let friend = friend else { return .empty() }
            let vc = FriendViewController(friend: friend)
            self.navigationController?.pushViewController(vc, animated: true)
            return .empty()
        }
        models = items.map {
            ContactItemModel(image: nil, title: $0.nickname,
                              caption: $0.statusMessage,
                              friend: $0,
                              action: action)
            }
            .group(by: {
                let title = $0.title as NSString
                let letters = PinyinHelper.toHanyuPinyinStringArray(withChar: title.character(at: 0)) as? [String]
                let firstCharacter = String(letters?.first?.prefix(1) ?? $0.title.prefix(1))
                return firstCharacter.isEnglishLetters() ? firstCharacter.uppercased() : "#"
            })
        let titles = models.keys.sorted(by: { l, r in
            let lIsEnglishLetters = l.isEnglishLetters()
            let rIsEnglishLetters = r.isEnglishLetters()
            if lIsEnglishLetters, rIsEnglishLetters {
                return l < r
            }
            return lIsEnglishLetters
        })
        
        sectionTitles = titles
        
        let topMenus = setupTopMenus()
        models[""] = topMenus
        sectionTitles.insert("", at: 0)
    }
    
    @objc private func addButtonClick(sender: UIButton) {
        let vc = AddFriendViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension ContactsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = sectionTitles[section]
        return models[key]?.count ?? 0
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let model = models[sectionTitles[indexPath.section]]?[indexPath.row] else {
            return UITableViewCell()
        }
        
        if indexPath.section == 0 {
            let cell: ContractMenuCell = tableView.dequeueReusableCell(for: indexPath)
            cell.iconImageView.image = model.image
            cell.nameLabel.text = model.title
            
            if indexPath.row == 0 {
                requestCount
                    .subscribe(onNext: { [weak cell] requests in
                        cell?.badgeView.isHidden = requests == 0
                        cell?.badgeView.text = "\(requests)"
                    })
                    .disposed(by: cell.disposeBag)
            }
            
            return cell
        } else {
            let cell: ContractDetailCell = tableView.dequeueReusableCell(for: indexPath)
            cell.avatarImageView.setFriendImage(friend: model.friend)
            cell.nameLabel.text = model.title
            cell.detailLabel.text = model.caption
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 44
        }
        return 64
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }
        return sectionTitles[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 30
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = UIColor("#83838D")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let model = models[sectionTitles[indexPath.section]]?[indexPath.row] else {
            return
        }
        
        model.action.execute(model.friend)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section > 0
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return NSLocalizedString("Delete", comment: "")
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let model = models[sectionTitles[indexPath.section]]?[indexPath.row],
                let friend = model.friend else {
                return
            }
            
            let deleteAction: AlertViewManager.Action = { [unowned self] in
                do {
                    let submanagerChats = UserService.shared.toxMananger!.chats
                    let chat = submanagerChats.getChatWith(friend)
                    
                    submanagerChats.removeAllMessages(in: chat, removeChat: true)
                    try self.submanagerFriends.remove(friend)
                }
                catch let error as NSError {
                    ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
                }
                return ()
            }
            
            let message = friend.publicKey == OfflineBotModel().publicKey
                ? NSLocalizedString("Delete this bot?\nYour offline messages will be lost.", comment: "")
                : NSLocalizedString("Delete this contact?\nYour chat history will be lost.", comment: "")
            AlertViewManager.showMessageSheet(with: message, actions: [
                (NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)
                ])
        }
    }
}

private extension ContactsViewController {
    func addNotificationBlocks() {
        requestsToken = requests.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let requests, _, let insert, _):
                guard let requests = requests else {
                    return
                }
                print("\(insert.count)")
                self.requestCount.accept(requests.count)
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        friendsToken = friends.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let results, _, let insertions, _):
                guard let results = results else { return }
                
                if insertions.count > 0 {
                    insertions.forEach { index in
                        let friend = results[index]
                        UserService.shared.toxMananger!.chats.getOrCreateChat(with: friend)
                    }
                }
                
                self.bindData()
                self.tableView.reloadData()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}

extension Sequence {
    func group<U: Hashable>(by key: (Iterator.Element) -> U) -> [U:[Iterator.Element]] {
        var categories: [U: [Iterator.Element]] = [:]
        for element in self {
            let key = key(element)
            if case nil = categories[key]?.append(element) {
                categories[key] = [element]
            }
        }
        return categories
    }
}
