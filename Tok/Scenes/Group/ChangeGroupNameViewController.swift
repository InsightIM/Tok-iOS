//
//  ChangeGroupNameViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2019/1/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ChangeGroupNameViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()
    
    fileprivate let chat: OCTChat
    
    init(chat: OCTChat) {
        self.chat = chat
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.dataSource = self
        
        tableView.rowHeight = 56
        tableView.sectionHeaderHeight = 40
        tableView.sectionFooterHeight = 0.01
        
        tableView.keyboardDismissMode = .interactive
        tableView.tableFooterView = UIView()
        
        return tableView
    }()
    
    let inputCell = GroupNameInputCell()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Modify Group Name", comment: "")
        
        inputCell.nameField.text = chat.title
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let next = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: nil, action: nil)
        next.tintColor = UIColor.tokLink
        next.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                guard let name = self.inputCell.nameField.text, name.isNotEmpty else {
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Group name is required", comment: ""), in: self.view)
                    return
                }
                
                let result = UserService.shared.toxMananger!.chats.setGroupTitleWithGroupNumber(self.chat.groupNumber, title: name)
                if result {
                    self.navigationController?.popViewController(animated: true)
                } else {
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Group name change failed", comment: ""), in: self.view)
                }
            })
            .disposed(by: disposeBag)
        navigationItem.rightBarButtonItem = next
    }
}

extension ChangeGroupNameViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return inputCell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Group Name", comment: "")
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = UIColor("#83838D")
    }
}
