//
//  EditGroupViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2019/1/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class EditGroupViewController: BaseViewController {
    
    enum EditGroupAction {
        case add
        case remove
        
        func toString() -> String {
            switch self {
            case .add:
                return NSLocalizedString("Add Members", comment: "")
            case .remove:
                return NSLocalizedString("Remove Members", comment: "")
            }
        }
    }

    private let disposeBag = DisposeBag()

    private var page: UInt32 = 0
    fileprivate var friends: [FriendSelectionViewModel] = []
    fileprivate let avatarManager = AvatarManager()
    
    private let chat: OCTChat
    private let action: EditGroupAction
    private let messageService: MessageService
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = 64
        tableView.register(cellType: FriendSelectionCell.self)
        
        tableView.sectionIndexColor = UIColor("#555567")
        tableView.sectionIndexBackgroundColor = UIColor.clear
        
        tableView.keyboardDismissMode = .interactive
        tableView.tableFooterView = UIView()
        
        tableView.allowsMultipleSelection = true
        return tableView
    }()
    
    lazy var searchView = SearchFriendsView()
    
    lazy var resultView = SearchResultView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = action.toString()
        
        let searchViewHeight = action == .add ? 55 : 0
        view.addSubview(searchView)
        searchView.snp.makeConstraints { (make) in
            make.height.equalTo(searchViewHeight)
            make.left.right.top.equalToSuperview()
        }
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(searchView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        view.addSubview(resultView)
        resultView.snp.makeConstraints { (make) in
            make.edges.equalTo(tableView)
        }
        
        let next = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: nil, action: nil)
        next.tintColor = .tokLink
        next.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                switch self.action {
                case .add:
                    let dataSource = self.friends.filter { $0.isSelected.value }.map { $0.friend }
                    dataSource.forEach { friend in
                        self.messageService.tokManager.toxManager.chats.invite(friend, toGroupChat: self.chat)
                    }
                case .remove:
                    let dataSource = self.friends.filter { $0.isSelected.value }.map { $0.peer }
                    dataSource.forEach { peer in
                        self.messageService.tokManager.toxManager.chats.kickoutPeer(peer?.publicKey, fromGroupChat: self.chat)
                    }
                }

                self.messageService.tokManager.toxManager.chats.getGroupInfo(withGroupNumber: self.chat.groupNumber)
                AvatarManager.shared.clearGroupImageCache(with: self.chat)
                self.navigationController?.popViewController(animated: true)
            })
            .disposed(by: disposeBag)
        navigationItem.rightBarButtonItem = next
        
        let selectedCountChanges = Observable.merge(friends.map { $0.isSelected.asObservable() })
            .map { [unowned self] _ -> Int in
                let count = self.friends.reduce(0) { (count, viewModel) in
                    count + (viewModel.isSelected.value ? 1 : 0)
                }
                return count
        }
        
        selectedCountChanges
            .map { $0 > 0 ? NSLocalizedString("Done", comment: "") + "(\($0))" : NSLocalizedString("Done", comment: "") }
            .bind(to: next.rx.title)
            .disposed(by: disposeBag)
        
        selectedCountChanges
            .map { $0 > 0 }
            .bind(to: next.rx.isEnabled)
            .disposed(by: disposeBag)
        
        selectedCountChanges
            .map { $0 == 0 }
            .bind(to: searchView.tableView.rx.isHidden)
            .disposed(by: disposeBag)
        
        selectedCountChanges
            .map { $0 == 0 }
            .bind(to: searchView.footerTextFiled.rx.isHidden)
            .disposed(by: disposeBag)
        
        Observable.merge(searchView.deselectedSubject, resultView.deselectedSubject)
            .subscribe(onNext: { [unowned self] viewModel in
                self.deselectViewModel(viewModel: viewModel)
            })
            .disposed(by: disposeBag)
        
        resultView.selectedSubject
            .subscribe(onNext: { [unowned self] viewModel in
                self.selectViewModel(viewModel: viewModel)
                self.searchView.searchTextFiled.text = ""
                self.searchView.footerTextFiled.text = ""
                self.searchView.footerTextFiled.becomeFirstResponder()
                _ = self.searchView.textFieldShouldBeginEditing(self.searchView.footerTextFiled)
                
                self.resultView.dataSource = []
                self.resultView.tableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        searchView.editing
            .map { !$0 }
            .bind(to: resultView.rx.isHidden)
            .disposed(by: disposeBag)
        
        Observable.merge(searchView.searchTextFiled.rx.text.orEmpty.asObservable(),
                         searchView.footerTextFiled.rx.text.orEmpty.asObservable())
            .subscribe(onNext: { [unowned self] text in
                self.resultView.dataSource = text.isNotEmpty
                    ? self.friends.filter { $0.name.lowercased().hasPrefix(text.lowercased()) }
                    : []
                self.resultView.tableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        if action == .remove {
            tableView.es.addInfiniteScrolling { [unowned self] in
                self.loadData()
            }
        }
    }
    
    private let peersCount: Int
    
    init(chat: OCTChat, action: EditGroupAction, messageService: MessageService) {
        self.chat = chat
        self.action = action
        self.messageService = messageService
        peersCount = chat.groupMemebersCount
        
        super.init()
        hidesBottomBarWhenPushed = true
        
        switch action {
        case .add:
            let realmFriends: [OCTFriend] = messageService.database.normalFriends().toList()
            friends = realmFriends
                .map { friend -> FriendSelectionViewModel in
                    return FriendSelectionViewModel(friend: friend, messageService:self.messageService, isDisabled: false)
            }
        case .remove:
            loadData()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadData() {
        let myPublicKey = messageService.tokManager.toxManager.user.publicKey
        if page == 0 {
            ProgressHUD.showLoadingHUD(in: self.view)
        }
         messageService.getPeerList(groupId: UInt64(chat.groupNumber), page: page)
            .subscribe(onNext: { [weak self] (peers, end) in
                if self?.page == 0 {
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                }
                self?.page += 1
                
                let list = peers
                    .filter {
                        $0.publicKey != myPublicKey
                    }
                    .map {
                        FriendSelectionViewModel(peer: $0)
                    }
                self?.friends.append(contentsOf: list)
                self?.tableView.reloadData()
                
                self?.tableView.es.stopLoadingMore()
                if end || peers.isEmpty {
                    self?.tableView.es.noticeNoMoreData()
                }
                }, onError: { [weak self] _ in
                    self?.tableView.es.stopLoadingMore()
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Something went wrong and try again later", comment: ""), in: self?.view)
            })
            .disposed(by: disposeBag)
    }
}

extension EditGroupViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = friends[indexPath.row]
        let cell: FriendSelectionCell = tableView.dequeueReusableCell(for: indexPath)
        cell.render(viewModel: viewModel)
        viewModel.indexPath = indexPath
        
        return cell
    }
}

extension EditGroupViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewModel = friends[indexPath.row]
        selectViewModel(viewModel: viewModel)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let viewModel = friends[indexPath.row]
        guard viewModel.isSelected.value == true else {
            return
        }
        
        deselectViewModel(viewModel: viewModel)
    }
    
    func selectViewModel(viewModel: FriendSelectionViewModel) {
        guard viewModel.isDisabled == false else {
            return
        }
        
        if let indexPath = viewModel.indexPath {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableView.ScrollPosition.none)
        }
        viewModel.isSelected.accept(true)
        searchView.addMember(viewModel: viewModel)
    }
    
    func deselectViewModel(viewModel: FriendSelectionViewModel) {
        guard viewModel.isDisabled == false else {
            return
        }
        
        if let indexPath = viewModel.indexPath {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        
        viewModel.isSelected.accept(false)
        searchView.removeMemeber(viewModel: viewModel)
    }
}
