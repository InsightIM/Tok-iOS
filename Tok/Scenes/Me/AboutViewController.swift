//
//  AboutViewController.swift
//  Tok
//
//  Created by Bryce on 2018/10/2.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SnapKit
import SafariServices
import StoreKit
import RxSwift

struct AboutModel {
    let cell: UITableViewCell
    let height: CGFloat
    let action: (() -> Void)?
}

class AboutViewController: BaseViewController {
    
    struct Constants {
        static let reddit = URL(string: "https://www.reddit.com/r/TokMessenger")
        static let twitter = URL(string: "https://twitter.com/TokMessenger")
        static let facebook = URL(string: "https://www.facebook.com/2460560374019007")
        static let appstore = URL(string: "https://apps.apple.com/app/tok-encrypted-messaging/id1455803201")
        static let devIds = ["8FACE4194BFDD4021FB5ED92A4B46546F64E8529BE200D13DD6426B8FCA10F592853D606F1BA",
                             "D1BCA4E4D9C620FE0BF815D8C8A2317AF79266F5F2750B909ED2BABDF6AC6264741BACF56B53"]
    }
    
    private let disposeBag = DisposeBag()
    let websiteSB = UIStoryboard(name: "website", bundle: nil)
    lazy var logoCell = UIView.ts_viewFromNib(LogoCell.self)
    lazy var updateCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Check for Update", comment: "")
        return cell
    }()
    lazy var websiteCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Website", comment: "")
        cell.rightLabel.copyable = true
//        cell.rightLabel.text = officalDomain
//        cell.copyButton.addTarget(self, action: #selector(self.didCopy), for: .touchUpInside)
        return cell
    }()
    lazy var contactUsCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Contact us", comment: "")
        cell.rightLabel.text = nil
        return cell
    }()
    lazy var privacyCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Security & Privacy", comment: "")
        cell.rightLabel.text = nil
        return cell
    }()
    lazy var redditCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Reddit", comment: "")
        cell.rightLabel.text = "r/TokMessenger"
        return cell
    }()
    lazy var twitterCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Twitter", comment: "")
        cell.rightLabel.text = "@TokMessenger"
        return cell
    }()
    lazy var facebookCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Facebook", comment: "")
        cell.rightLabel.text = "@TokMessenger"
        return cell
    }()
    lazy var termsCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Terms of Service", comment: "")
        cell.rightLabel.text = nil
        return cell
    }()
    lazy var rateCell: AboutItemCell = {
        let cell = UIView.ts_viewFromNib(AboutItemCell.self)
        cell.leftLabel.text = NSLocalizedString("Rate Tok", comment: "")
        cell.rightLabel.text = nil
        return cell
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .tokBackgroundColor
        tableView.separatorColor = .tokLine
        tableView.sectionHeaderHeight = 12
        tableView.sectionFooterHeight = 0.01
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    lazy var versionLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .tokFootnote
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? ""
        #if DEBUG
        let bundleVersion = info?["CFBundleVersion"] as? String ?? ""
        let version = shortVersion + " (\(bundleVersion))"
        #else
        let version = shortVersion
        #endif
        label.text = NSLocalizedString("Version", comment: "") + " \(version)"
        return label
    }()
    
    var versionInfo: VersionInfo?
    
    lazy var versionCode: Int = {
        if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let versions = versionString.components(separatedBy: ".")
            let scales = [10000, 100, 1]
            var vCode = 0
            for i in 0 ..< scales.count {
                if i < versions.count, let v = Int(versions[i]) {
                    vCode = vCode + v * scales[i]
                }
            }
            return vCode
        }
        return 0
    }()
    
    var dataSource: [[AboutModel]] = []
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("About Tok", comment: "")
        view.backgroundColor = .tokBackgroundColor
        
        view.addSubview(tableView)
        view.addSubview(versionLabel)
        
        checkVersion()
        
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.safeArea.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(versionLabel.snp.top).offset(-20)
        }
        versionLabel.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-20)
        }
        
        dataSource.append([AboutModel(cell: logoCell, height: 138, action: nil)])
        dataSource.append([
            AboutModel(cell: updateCell, height: 44, action: { [weak self] in
                guard let self = self else { return }
                if let vInfo = self.versionInfo {
                    if vInfo.versionCode > self.versionCode {
                        let title = NSLocalizedString("What’s New", comment: "")
                        let alertVC = UIAlertController(title: title, message: nil, preferredStyle: .alert)
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .left
                        paragraphStyle.lineSpacing = 5
                        let messageText = NSMutableAttributedString(
                            string: vInfo.updateDesc ?? "",
                            attributes: [
                                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                                NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14.0, weight: .regular),
                                NSAttributedString.Key.foregroundColor : UIColor.black
                            ]
                        )
                        alertVC.setValue(messageText, forKey: "attributedMessage")
                        let leftAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: nil)
                        alertVC.addAction(leftAction)
                        let rightAction = UIAlertAction(title: NSLocalizedString("Update", comment: ""), style: .default, handler: { [weak self] action in
                            guard let self = self else { return }
                            if let languageCode = NSLocale.current.languageCode, languageCode.contains("zh") {
                                if let vc = self.websiteSB.instantiateViewController(withIdentifier: "DownHelpCNController") as? DownHelpCNController {
                                    vc.dataList = vInfo.accounts
                                    self.navigationController?.pushViewController(vc, animated: true)
                                }
                            } else {
                                UIApplication.shared.open(URL(string: "https://itunes.apple.com/us/app/1455803201")!,
                                                          completionHandler: nil)
                            }
                        })
                        alertVC.addAction(rightAction)
                        
                        self.present(alertVC, animated: true, completion: nil)
                    } else {
                        ProgressHUD.showTextHUD(withText: NSLocalizedString("This is the latest version", comment: ""), in: self.view)
                    }
                }
            }),
            AboutModel(cell: websiteCell, height: 44, action: { [weak self] in
                guard let self = self else { return }
                if let vc = self.websiteSB.instantiateViewController(withIdentifier: "WebSiteController") as? WebSiteController {
                    if let websites = self.versionInfo?.officialWebsite {
                        vc.dataList = websites
                    }
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }),
            AboutModel(cell: contactUsCell, height: 44, action: { [unowned self] in
                let randomIndex = Int(arc4random() % 2)
                let tokID = Constants.devIds[randomIndex]
                let vc = AddFriendViewController(messageService: self.messageService)
                vc.didScanHander(tokID)
                self.navigationController?.pushViewController(vc, animated: true)
            }),
            AboutModel(cell: privacyCell, height: 44, action: { [weak self] in
                self?.presentPrivacy()
            })])
        
        dataSource.append([
            AboutModel(cell: redditCell, height: 44, action: { [weak self] in
                guard let url = Constants.reddit else { return }
                let vc = SFSafariViewController(url: url)
                self?.present(vc, animated: true)
            }),
            AboutModel(cell: twitterCell, height: 44, action: { [weak self] in
                guard let url = Constants.twitter else { return }
                let vc = SFSafariViewController(url: url)
                self?.present(vc, animated: true)
            }),
            AboutModel(cell: facebookCell, height: 44, action: { [weak self] in
                guard let url = Constants.facebook else { return }
                let vc = SFSafariViewController(url: url)
                self?.present(vc, animated: true)
            })])
        
        dataSource.append([
            AboutModel(cell: termsCell, height: 44, action: { [weak self] in
                let vc = TermsViewController()
                self?.present(vc, animated: true)
            }),
            AboutModel(cell: rateCell, height: 44, action: { [weak self] in
                guard let url = Constants.appstore else { return }
                let vc = SFSafariViewController(url: url)
                self?.present(vc, animated: true)
            })])
    }
    
    func checkVersion() {
        
        ProgressHUD.showLoadingHUD(in: self.view)
        self.messageService.sendVersionInfoRequest().subscribe (onNext: { [weak self] (vInfo) in
            guard let self = self else { return }
            ProgressHUD.hideLoadingHUD(in: self.view)
            
            self.versionInfo = vInfo
            if vInfo.versionCode > self.versionCode {
                self.updateCell.version = vInfo.version
            }
            
            UserDefaultsManager().checkUpdateVersionCode = Int(vInfo.versionCode)
            UserDefaultsManager().checkUpdateVersion = vInfo.version ?? ""
            
        }, onError: {  [weak self] _ in
            ProgressHUD.hideLoadingHUD(in: self?.view)
        }).disposed(by: self.disposeBag)
    }
    
    @objc
    private func didCopy() {
        UIPasteboard.general.string = officalLink
        ProgressHUD.showTextHUD(withText: NSLocalizedString("The link has been copied to the clipboard", comment: ""), in: self.view)
    }
}

extension AboutViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dataSource[indexPath.section][indexPath.row].cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return dataSource[indexPath.section][indexPath.row].height
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section == 2 else { return 12 }
        return 30
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section == 2 else { return "" }
        return NSLocalizedString("Follow us", comment: "").uppercased()
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 12)
        header.textLabel?.textColor = .tokBlack
        header.backgroundView?.backgroundColor = .tokBackgroundColor
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dataSource[indexPath.section][indexPath.row].action?()
    }
}
