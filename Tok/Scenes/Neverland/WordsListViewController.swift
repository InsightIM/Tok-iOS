//
//  WordsListViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class WordsListViewController: BaseViewController {
    
    var dataSource: [String] = []
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorColor = .clear
        tableView.estimatedRowHeight = 85
        tableView.allowsSelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellType: WordsCell.self)
        return tableView
    }()
    
    lazy var doneItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: self, action: #selector(self.didDone))
    
    var didSelect: ((String) -> Void)?
    
    private let findFriendService: FindFriendService
    init(findFriendService: FindFriendService) {
        self.findFriendService = findFriendService
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Classical words", comment: "")
        view.backgroundColor = .tokBackgroundColor
        navigationItem.rightBarButtonItem = doneItem
        doneItem.isEnabled = false
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.top.equalTo(self.view.safeArea.top).offset(12)
            make.bottom.equalTo(self.view.safeArea.bottom)
        }

        dataSource = findFriendService.loadClassicWords()
    }
    
    @objc
    func didDone() {
        guard let selectedRow = tableView.indexPathForSelectedRow else {
            return
        }
        didSelect?(dataSource[selectedRow.section])
        navigationController?.popViewController(animated: true)
    }
}

extension WordsListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: WordsCell.self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        cell.contentLabel.attributedText = NSAttributedString(string: dataSource[indexPath.section],
                                                              attributes: [.paragraphStyle: paragraphStyle,
                                                                           .font: UIFont.systemFont(ofSize: 16)])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 8
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        doneItem.isEnabled = tableView.indexPathForSelectedRow != nil
    }
}
