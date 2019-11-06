//
//  SearchFriendsView.swift
//  Tok
//
//  Created by Bryce on 2018/12/30.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SearchFriendsView: UIView {
    
    private let disposeBag = DisposeBag()

    private let footerMinSize: CGFloat = 120
    
    let deselectedSubject = PublishSubject<FriendSelectionViewModel>()
    
    let editing = BehaviorRelay(value: false)
    
    lazy var searchTextFiled: UITextField = {
        let searchTextField = UITextField()
        
        searchTextField.placeholder = NSLocalizedString("Search", comment: "")
        searchTextField.font = UIFont.systemFont(ofSize: 16)
        let imageView = UIImageView()
        imageView.frame = CGRect(x: 0, y: 0, width: 55, height: 55)
        imageView.contentMode = .center
        imageView.image = UIImage(named: "GroupSearch")
        searchTextField.leftViewMode = .always
        searchTextField.leftView = imageView
        
        searchTextField.delegate = self
        return searchTextField
    }()
    
    lazy var footerTextFiled: UITextField = {
        let searchTextField = UITextField()
        searchTextField.placeholder = NSLocalizedString("Search", comment: "")
        searchTextField.font = UIFont.systemFont(ofSize: 16)
        searchTextField.backgroundColor = .white
        searchTextField.delegate = self
        return searchTextField
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.transform = CGAffineTransform(rotationAngle: -.pi/2)
        tableView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - footerMinSize, height: 55)
        tableView.showsVerticalScrollIndicator = false
        
        tableView.separatorStyle = .none
        tableView.dataSource = self
        
        tableView.rowHeight = 55
        tableView.register(cellType: GroupMemeberCell.self)
        
        tableView.tableFooterView = UIView()
        
        tableView.allowsMultipleSelection = false
        return tableView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(searchTextFiled)
        searchTextFiled.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        addSubview(tableView)
        addSubview(footerTextFiled)
        
        let lineView = UIView()
        lineView.backgroundColor = UIColor.tokLine
        addSubview(lineView)
        lineView.snp.makeConstraints { (make) in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(1.0)
        }
        
        footerTextFiled.rx.sentMessage(#selector(footerTextFiled.deleteBackward))
            .subscribe(onNext: { [unowned self] _ in
                let lastIndex = IndexPath(row: self.members.count - 1, section: 0)
                guard self.footerTextFiled.text?.isEmpty == true else {
                    return
                }
                
                if let index = self.tableView.indexPathForSelectedRow {
                    self.deselectedSubject.onNext(self.members[index.row])
                } else {
                    self.tableView.selectRow(at: lastIndex, animated: false, scrollPosition: UITableView.ScrollPosition.none)
                }
            })
            .disposed(by: disposeBag)
        
        footerTextFiled.rx.text.orEmpty
            .subscribe(onNext: { [unowned self] text in
                if text.isNotEmpty, let index = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: index, animated: false)
                }
            })
            .disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var members: [FriendSelectionViewModel] = []
    
    func addMember(viewModel: FriendSelectionViewModel) {
        let index = members.firstIndex { $0.uniqueIdentifier == viewModel.uniqueIdentifier }
        guard index == nil else {
            return
        }
        members.append(viewModel)
        tableView.reloadData()
        DispatchQueue.main.async {
            self.tableView.setOffsetToBottom(animated: true)
            self.updateFooterView()
            //scrollToRow(at: IndexPath(row: self.members.count - 1, section: 0), at: .bottom, animated: true)
        }
    }
    
    func removeMemeber(viewModel: FriendSelectionViewModel) {
        let index = members.firstIndex { $0.uniqueIdentifier == viewModel.uniqueIdentifier }
        guard let row = index else {
            return
        }
        
        members.remove(at: row)
        tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .none)
        updateFooterView()
        
        if members.isEmpty {
            footerTextFiled.resignFirstResponder()
        }
    }
    
    func updateFooterView() {
        let offset = tableView.contentSize.height - tableView.bounds.size.height
        let width = CGFloat.maximum(footerMinSize, footerMinSize - offset)
        
        let x = UIScreen.main.bounds.width - width
        footerTextFiled.frame = CGRect(x: x, y: 0, width: width, height: 55)
    }
}

extension SearchFriendsView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GroupMemeberCell = tableView.dequeueReusableCell(for: indexPath)
        cell.render(viewModel: members[indexPath.row])
        return cell
    }
}

extension SearchFriendsView: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        editing.accept(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        editing.accept(false)
    }
}

class GroupMemeberCell: UITableViewCell {
    
    var viewModel: FriendSelectionViewModel!
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.setTokCornerRadiusStyle()
        return imageView
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .gray
        contentView.transform = CGAffineTransform(rotationAngle: .pi/2)
        
        contentView.addSubview(avatarImageView)
        
        avatarImageView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(44)
        }
        
//        nameLabel.snp.makeConstraints { (make) in
//            make.top.equalTo(avatarImageView.snp.bottom).offset(4)
//            make.left.right.equalToSuperview()
//        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func render(viewModel: FriendSelectionViewModel) {
        self.viewModel = viewModel
        
        avatarImageView.image = viewModel.image
    }
}

fileprivate extension UITableView {
    func setOffsetToBottom(animated: Bool) {
        let offset = contentSize.height - bounds.size.height
        guard offset > 0 else {
            return
        }
        setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
    }
}
