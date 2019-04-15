//
//  AboutViewController.swift
//  Tok
//
//  Created by Bryce on 2018/10/2.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SnapKit

fileprivate let kAbloutButtonTagBase = 300

enum AboutListType {
    case version
    case tok
}

struct AboutModel {
    
    var listType: AboutListType = .version
    var title: String?
    var desc: String?
    var isHiddenIndicator: Bool = false
}

class AboutViewController: BaseViewController {

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        return scrollView
    }()
    
    lazy var reserveLabel: UILabel = {
        let reserveLabel = UILabel()
        reserveLabel.font = UIFont.systemFont(ofSize: 15)
        reserveLabel.textColor = UIColor.tokBlack.withAlphaComponent(0.4)
        reserveLabel.textAlignment = .center
        reserveLabel.adjustsFontSizeToFitWidth = true
        reserveLabel.text = String(format: NSLocalizedString("%ld Tok all rights reserved", comment: ""), Date().year)
        return reserveLabel
    }()
    
    var models: [AboutModel]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("About Tok", comment: "")
        self.setupViews()
    }
    
    func setupViews() {
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        scrollView.alwaysBounceVertical = true
        
        let logoView = UIImageView()
        logoView.image = UIImage(named: "logo")
        self.scrollView.addSubview(logoView)
        logoView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(16)
        }
        
        let despLabel = UILabel()
        despLabel.numberOfLines = 0
        despLabel.font = UIFont.systemFont(ofSize: 15)
        despLabel.textColor = UIColor.tokBlack
        despLabel.textAlignment = .center
        despLabel.text = NSLocalizedString("Make the world connect freely!", comment: "")
        self.scrollView.addSubview(despLabel)
        despLabel.snp.makeConstraints { (make) in
            make.left.equalTo(26)
            make.right.equalTo(-26)
            make.width.equalTo(UIScreen.main.bounds.width - 26 * 2)
            make.top.equalTo(logoView.snp.bottom).offset(26)
        }
        
        let blankView = UIView()
        blankView.backgroundColor = UIColor("#f5f5f5")
        self.scrollView.addSubview(blankView)
        blankView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.height.equalTo(12)
            make.top.equalTo(despLabel.snp.bottom).offset(12)
        }
        
        let tableView = UIView()
        self.scrollView.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.left.right.bottom.equalToSuperview()
            make.width.equalTo(UIScreen.main.bounds.width)
            make.top.equalTo(blankView.snp.bottom)
        }
        self.setupTableView(tableView)
        
        self.view.addSubview(reserveLabel)
        self.reserveLabel.snp.makeConstraints { (make) in
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-18)
        }
    }
    
    func setupTableView(_ table: UIView) {
        
        var version: String {
            get {
                let info = Bundle.main.infoDictionary
                let shortVersion = info?["CFBundleShortVersionString"] as? String ?? ""
                let bundleVersion = info?["CFBundleVersion"] as? String ?? ""
                return shortVersion + " (\(bundleVersion))"
            }
        }
        
        var firstModel = AboutModel()
        firstModel.title = NSLocalizedString("Current version", comment: "")
        firstModel.desc = version
        firstModel.listType = .version
        firstModel.isHiddenIndicator = true
        
        var secondModel = AboutModel()
        secondModel.listType = .tok
        secondModel.title = NSLocalizedString("Contact us", comment: "")
        secondModel.desc = ""
        
        let modelArray = [firstModel, secondModel]
        self.models = modelArray
        
        var lastCell: SingleLineCollectionViewCell?
        for (index, model) in modelArray.enumerated() {
            let cell = SingleLineCollectionViewCell()
            cell.model = (model.title ?? "", model.desc ?? "")
            cell.indicatorView.isHidden = model.isHiddenIndicator
            table.addSubview(cell)
            cell.snp.makeConstraints({ (make) in
                make.left.equalTo(24)
                make.right.equalTo(-24)
                make.height.equalTo(65)
                if let lastCell = lastCell {
                    make.top.equalTo(lastCell.snp.bottom)
                } else {
                    make.top.equalToSuperview()
                }
                if index == modelArray.count - 1 {
                    make.bottom.equalToSuperview()
                }
            })
            
            let btn = UIButton()
            btn.addTarget(self, action: #selector(self.cellDidSelect(_:)), for: .touchUpInside)
            cell.addSubview(btn)
            btn.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            btn.tag = kAbloutButtonTagBase + index
            
            lastCell = cell
        }
    }
    
    @objc func cellDidSelect(_ sender: UIButton) {
        guard let models = self.models else { return }
        let index = sender.tag - kAbloutButtonTagBase
        if models.count > index {
            let model = models[index]
            switch model.listType {
            case .version :
                return
            case .tok:
                let tokID = "D1BCA4E4D9C620FE0BF815D8C8A2317AF79266F5F2750B909ED2BABDF6AC6264741BACF56B53"
                let vc = AddFriendViewController()
                vc.didScanHander(tokID)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
