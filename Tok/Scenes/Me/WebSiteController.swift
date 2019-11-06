//
//  WebSiteController.swift
//  Tok
//
//  Created by gaven on 2019/10/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import SafariServices

class WebSiteController: BaseViewController {

    @IBOutlet var tableView: UITableView!
    var dataList = [String]()
    
    override init() {
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadData()
    }
    
    func loadData() {
        dataList.insert("https://www.tok.life", at: 0)
        self.tableView.reloadData();
    }
    
}

extension WebSiteController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WebSiteCell", for: indexPath) as! WebSiteCell
        cell.name = dataList[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let text = dataList[indexPath.row]
        guard let url = URL(string: text) else { return }
        let vc = SFSafariViewController(url: url)
        present(vc, animated: true, completion: nil)
    }
}
