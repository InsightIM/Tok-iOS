//
//  SearchResultView.swift
//  Tok
//
//  Created by Bryce on 2018/12/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SearchResultView: UIView {

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
    
    var dataSource: [FriendSelectionViewModel] = []
    
    let selectedSubject = PublishSubject<FriendSelectionViewModel>()
    let deselectedSubject = PublishSubject<FriendSelectionViewModel>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SearchResultView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: FriendSelectionCell = tableView.dequeueReusableCell(for: indexPath)
        let viewModel = dataSource[indexPath.row]
        cell.render(viewModel: viewModel)
        if viewModel.isSelected.value {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableView.ScrollPosition.none)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Contacts", comment: "")
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

extension SearchResultView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewModel = dataSource[indexPath.row]
        selectedSubject.onNext(viewModel)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let viewModel = dataSource[indexPath.row]
        deselectedSubject.onNext(viewModel)
    }
}
