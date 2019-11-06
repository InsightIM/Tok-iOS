//
//  GroupChatsViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2018/12/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import DeepDiff

class GroupChatsViewController: BaseViewController {
    
    fileprivate var chatsToken: RLMNotificationToken?
    
    fileprivate let dateFormatter: DateFormatter
    fileprivate let timeFormatter: DateFormatter
    
    private var items: [ChatsViewModel] = []
    
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
        
        title = NSLocalizedString("Group Chat", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    private let messageService: MessageService
    private let toxMananger: OCTManager
    private let messageSender: MessagesSender
    private lazy var avatarCache = NSCache<AnyObject, UIImage>()
    
    init(messageService: MessageService) {
        self.messageService = messageService
        self.toxMananger = messageService.tokManager.toxManager
        self.messageSender = messageService.messageSender
        
        self.dateFormatter = DateFormatter(type: .relativeDate)
        self.timeFormatter = DateFormatter(type: .time)
        
        super.init()
        
        hidesBottomBarWhenPushed = true
        updateModels()
        addNotificationBlocks()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        chatsToken?.invalidate()
    }
}

extension GroupChatsViewController: UITableViewDelegate, UITableViewDataSource {
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
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let chat = messageService.database.findChat(byId: items[indexPath.row].id) else {
            return
        }
        
        let vc = ConversationViewController()
        vc.dataSource = ConversationDataSource(messageService: messageService, chat: chat)
        navigationController?.pushViewController(vc, animated: true)
    }
}

private extension GroupChatsViewController {
    func addNotificationBlocks() {
        let chats = findSortedChats()
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
    }
    
    private func findSortedChats() -> Results<OCTChat> {
        return messageService.database.normalChats(onlyGroup: true).sortedResultsUsingProperty("lastActivityDateInterval", ascending: false)
    }
    
    private func updateModels() {
        DispatchQueue.global(qos: .userInitiated).async {
            let chats = self.findSortedChats()
            let newItems = chats.toList().map { ChatsViewModel(chat: $0, messageService: self.messageService, timeFormatter: self.timeFormatter, dateFormatter: self.dateFormatter, cache: self.avatarCache) }
            let oldItems = self.items
            
            let changes = diff(old: oldItems, new: newItems)
            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    self.tableView.reload(changes: changes,
                                          insertionAnimation: .none,
                                          deletionAnimation: .none,
                                          replacementAnimation: .none,
                                          updateData: {
                                            self.items = newItems
                    })
                }
            }
        }
    }
}
