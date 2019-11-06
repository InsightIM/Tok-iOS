//
//  DownHelpCNController.swift
//  Tok
//
//  Created by gaven on 2019/11/2.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift

class DownHelpCNController: BaseViewController {
    
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var item2View: UIView!
    @IBOutlet weak var accountConstraintH: NSLayoutConstraint!
    
    var dataList = [VersionInfo.AppleAccount]()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        loadData()
    }
    
    func setupView() {
        guard let attributedText = topLabel.attributedText else {
            return
        }
        let mutaAtt = NSMutableAttributedString(attributedString: attributedText)
        mutaAtt.addAttributes([NSAttributedString.Key.foregroundColor : UIColor.tokLink], range: NSMakeRange(52, 25))
        topLabel.attributedText = mutaAtt
    }

    func loadData() {
        self.accountConstraintH.constant = CGFloat(30 * self.dataList.count)
        self.tableView.reloadData();
    }
    
    @objc
    @IBAction func jumpAction() {
        UIApplication.shared.open(URL(string: "https://itunes.apple.com/us/app/1455803201")!,
                                  completionHandler: nil)
    }
}

extension DownHelpCNController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownHelpCell", for: indexPath) as! DownHelpCell
        cell.account = dataList[indexPath.row]
        return cell
    }
}
