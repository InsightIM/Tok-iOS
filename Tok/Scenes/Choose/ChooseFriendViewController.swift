//
//  ChooseFriendViewController.swift
//  Tok
//
//  Created by Bryce on 2019/1/21.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ChooseFriendViewController: BaseViewController {

    internal let disposeBag = DisposeBag()
    
    internal let friends: [FriendSelectionViewModel]
    
    fileprivate let avatarManager = AvatarManager()
    
    fileprivate var sectionTitles = [String]()
    fileprivate var models = [String: [FriendSelectionViewModel]]()
    
    private(set) var selectedCountChanges: Observable<Int>!
    
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
    
    lazy var rightBarButtonItem: UIBarButtonItem = {
        let next = UIBarButtonItem(title: NSLocalizedString("Next", comment: ""), style: .plain, target: self, action: #selector(ChooseFriendViewController.rightBarButtonItemClick(sender:)))
        next.tintColor = UIColor.tokLink
        return next
    }()
    
    lazy var searchView = SearchFriendsView()
    
    lazy var resultView = SearchResultView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Create Group", comment: "")
        
        view.addSubview(searchView)
        searchView.snp.makeConstraints { (make) in
            make.height.equalTo(55)
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
        
        navigationItem.rightBarButtonItem = rightBarButtonItem
        
        selectedCountChanges = Observable.merge(friends.map { $0.isSelected.asObservable() })
            .map { [unowned self] _ -> Int in
                let count = self.friends.reduce(0) { (count, viewModel) in
                    count + (viewModel.isSelected.value ? 1 : 0)
                }
                return count
        }
        
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
                    ? self.friends.filter { $0.name.hasPrefix(text) }
                    : []
                self.resultView.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }
    
    override init() {
        let realmFriends = UserService.shared.toxMananger!.objects.friends()
        friends = realmFriends.toList().map { FriendSelectionViewModel(friend: $0) }
        
        super.init()
        
        hidesBottomBarWhenPushed = true
        bindData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    func rightBarButtonItemClick(sender: Any?) {
        
    }
    
    private func bindData() {
        models = friends
            .group(by: {
                let title = $0.name as NSString
                let letters = PinyinHelper.toHanyuPinyinStringArray(withChar: title.character(at: 0)) as? [String]
                let firstCharacter = String(letters?.first?.prefix(1) ?? $0.name.prefix(1))
                return firstCharacter.isEnglishLetters() ? firstCharacter.uppercased() : "#"
            })
        sectionTitles = models.keys.sorted(by: { l, r in
            let lIsEnglishLetters = l.isEnglishLetters()
            let rIsEnglishLetters = r.isEnglishLetters()
            if lIsEnglishLetters, rIsEnglishLetters {
                return l < r
            }
            return lIsEnglishLetters
        })
    }
}

extension ChooseFriendViewController: UITableViewDataSource {
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
        guard let viewModel = models[sectionTitles[indexPath.section]]?[indexPath.row] else {
            return UITableViewCell()
        }
        
        let cell: FriendSelectionCell = tableView.dequeueReusableCell(for: indexPath)
        cell.render(viewModel: viewModel)
        viewModel.indexPath = indexPath
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = UIColor("#83838D")
    }
}

extension ChooseFriendViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = models[sectionTitles[indexPath.section]]?[indexPath.row],
            viewModel.isSelected.value == false else {
                return
        }
        
        selectViewModel(viewModel: viewModel)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let viewModel = models[sectionTitles[indexPath.section]]?[indexPath.row],
            viewModel.isSelected.value == true else {
                return
        }
        
        deselectViewModel(viewModel: viewModel)
    }
    
    func selectViewModel(viewModel: FriendSelectionViewModel) {
        if let indexPath = viewModel.indexPath {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableView.ScrollPosition.none)
        }
        viewModel.isSelected.accept(true)
        searchView.addMember(viewModel: viewModel)
    }
    
    func deselectViewModel(viewModel: FriendSelectionViewModel) {
        if let indexPath = viewModel.indexPath {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        
        viewModel.isSelected.accept(false)
        searchView.removeMemeber(viewModel: viewModel)
    }
}

