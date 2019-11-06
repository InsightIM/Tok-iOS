//
//  DonateViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/10.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class DonateViewController: BaseViewController {
    
    lazy var descCell: UITableViewCell = {
        let cell = UITableViewCell()
        let desc = NSLocalizedString("Donate_Desc", comment: "")
        let html = """
        <style>
        body {
        font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        font-size: 15px;
        text-align: center;
        color: #18181D;
        line-height:21px;
        }
        </style>
        <body>\(desc)</body>
        """
        if let data = html.data(using: .utf8),
            let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
            cell.textLabel?.attributedText = attributedString
        } else {
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
            cell.textLabel?.text = desc
        }
        cell.textLabel?.numberOfLines = 0
        return cell
    }()
    
    lazy var didCopy: ((String?) -> Void) = { [weak self] address in
        UIPasteboard.general.string = address
        ProgressHUD.showTextHUD(withText:
            NSLocalizedString("The address has been copied to the clipboard", comment: ""), in: self?.view)
    }
    
    lazy var btcCell: DigitalCurrencyCell = {
        let cell = UIView.ts_viewFromNib(DigitalCurrencyCell.self)
        cell.iconImageView.image = UIImage(named: "BTC")
        cell.nameLabel.text = NSLocalizedString("BTC Address", comment: "")
        cell.addressLabel.text = "3FG2U46VVzULCUCVm2K7foyXMZEV2RQEXf"
        cell.didCopy = didCopy
        return cell
    }()
    
    lazy var ethCell: DigitalCurrencyCell = {
        let cell = UIView.ts_viewFromNib(DigitalCurrencyCell.self)
        cell.iconImageView.image = UIImage(named: "ETH")
        cell.nameLabel.text = NSLocalizedString("ETH Address", comment: "")
        cell.addressLabel.text = "0x7E52D56937D8e71B35af52B162196aCA32E31B30"
        cell.didCopy = didCopy
        return cell
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .tokBackgroundColor
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 20
        tableView.sectionFooterHeight = 0.01
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    var dataSource: [[UITableViewCell]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Donate", comment: "")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }

        dataSource.append([descCell])
        dataSource.append([btcCell])
        dataSource.append([ethCell])
    }
}

extension DonateViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dataSource[indexPath.section][indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 12 : tableView.sectionHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.backgroundView?.backgroundColor = .tokBackgroundColor
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
