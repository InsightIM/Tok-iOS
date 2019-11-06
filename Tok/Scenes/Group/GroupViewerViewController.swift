//
//  GroupViewerViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class GroupViewerCell: UITableViewCell {
    
    lazy var leftLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .tokTitle4
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var verifiedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ChatVerified")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [leftLabel, verifiedImageView])
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    lazy var rightLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .tokFootnote
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(stackView)
        contentView.addSubview(rightLabel)
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rightLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        stackView.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(44).priorityHigh()
        }
        
        rightLabel.snp.makeConstraints { (make) in
            make.leading.greaterThanOrEqualTo(stackView.snp.trailing).offset(8)
            make.top.bottom.equalToSuperview()
            make.trailing.equalTo(-10)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GroupViewerViewController: BaseViewController {

    private let disposeBag = DisposeBag()
    
    private let groupShareId: String
    private let toxManager: OCTManager
    private let messageService: MessageService
    init(groupShareId: String, messageService: MessageService) {
        self.groupShareId = groupShareId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.messageService = messageService
        self.toxManager = messageService.tokManager.toxManager
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var groupNameCell = GroupViewerCell()
    
    lazy var groupTypeCell = GroupViewerCell()
    
    lazy var descCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .tokFootnote
        cell.textLabel?.numberOfLines = 0
        return cell
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.sectionHeaderHeight = 12
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.separatorColor = .tokLine
        tableView.tableFooterView = footerView
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 12))
        return tableView
    }()
    
    lazy var joinButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Join Group", comment: ""))
        button.addTarget(self, action: #selector(self.didClickJoin), for: .touchUpInside)
        return button
    }()
    
    lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        
        let border = UIView()
        border.backgroundColor = UIColor.tokLine
        view.addSubview(border)
        border.snp.makeConstraints { (make) in
            make.height.equalTo(1.0 / UIScreen.main.scale)
            make.left.right.top.equalToSuperview()
        }
        
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Group Info", comment: "")
        tableView.backgroundColor = .tokBackgroundColor
        
        footerView.addSubview(joinButton)
        joinButton.snp.makeConstraints({ (make) in
            make.top.equalTo(20).priority(.high)
            make.left.equalTo(16).priority(.high)
            make.right.equalTo(-16).priority(.high)
            make.height.equalTo(50)
        })
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        bindData()
    }
    
    private var groupInfo: GroupInfoModel?
    private func bindData() {
        guard toxManager.managerGetTox()!.shareIdIsValid(groupShareId) else {
            showError(errorMessage: NSLocalizedString("Unable to view or group does not exist", comment: ""))
            return
        }
        guard let groupNumber = groupShareId.matchGroupNumber() else {
            showError()
            return
        }
        
        ProgressHUD.showLoadingHUD(in: self.view)
        messageService.fetch(groupInfo: UInt64(groupNumber))
            .subscribe(onNext: { [weak self] model in
                guard let self = self else { return }
                ProgressHUD.hideLoadingHUD(in: self.view)
                self.groupInfo = model
                self.tableView.reloadData()
                }, onError: { [weak self] _ in
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                    self?.showError()
            })
            .disposed(by: disposeBag)
    }
    
    func showError(errorMessage: String = NSLocalizedString("Something went wrong and try again later", comment: "")) {
        AlertViewManager.showMessageSheet(with: errorMessage,
                                          interactive: false,
                                          cancelTitle: NSLocalizedString("OK", comment: ""),
                                          customCancelAction: { [weak self] in
                                            self?.navigationController?.popViewController(animated: true)
        })
    }
    
    @objc
    func didClickJoin() {
        guard let groupNumber = groupShareId.matchGroupNumber() else {
            showError()
            return
        }
        if let chat = messageService.database.findGroupChat(by: UInt64(groupNumber)) {
            NotificationCenter.default.post(name: NSNotification.Name.ShowChat, object: nil, userInfo: ["chat": chat])
            return
        }
        
        ProgressHUD.showLoadingHUD(in: self.view)
        messageService.join(group: groupShareId)
            .subscribe(onNext: { [weak self] groupNumber in
                guard let self = self else { return }
                ProgressHUD.hideLoadingHUD(in: self.view)
                guard let chat = self.messageService.database.findOrCreateGroupChat(by: UInt64(groupNumber)) else {
                    AlertViewManager.showMessageSheet(with: NSLocalizedString("Sorry, this group chat is no longer accessible.", comment: ""),
                                                      cancelTitle: NSLocalizedString("OK", comment: ""))
                    return
                }
                self.messageService.fetch(groupInfo: UInt64(groupNumber)).subscribe().disposed(by: self.disposeBag)
                NotificationCenter.default.post(name: NSNotification.Name.ShowChat, object: nil, userInfo: ["chat": chat])
                }, onError: { [weak self] _ in
                    ProgressHUD.hideLoadingHUD(in: self?.view)
                    ProgressHUD.showTextHUD(withText: NSLocalizedString("Something went wrong and try again later", comment: ""), in: self?.view)
            })
            .disposed(by: disposeBag)
    }
}

extension GroupViewerViewController: UITableViewDataSource, UITableViewDelegate{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let groupInfo = groupInfo else {
            return UITableViewCell()
        }
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let cell = groupNameCell
                cell.leftLabel.text = groupInfo.title
                cell.verifiedImageView.isHidden = !verifiedGroupShareIds.contains(groupInfo.shareId)
                cell.rightLabel.text = "\(groupInfo.membersNum) " + NSLocalizedString("Members", comment: "").uppercased()
                return cell
            } else {
                let cell = groupTypeCell
                cell.leftLabel.text = NSLocalizedString("Group Type", comment: "")
                cell.rightLabel.text = groupInfo.type == 0 ? NSLocalizedString("Private", comment: "") : NSLocalizedString("Public", comment: "")
                return cell
            }
        default:
            let cell = descCell
            cell.textLabel?.text = groupInfo.desc?.isNotEmpty == true ? groupInfo.desc : NSLocalizedString("No group description", comment: "")
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
            cell.textLabel?.textColor = .tokFootnote
            cell.textLabel?.numberOfLines = 0
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
