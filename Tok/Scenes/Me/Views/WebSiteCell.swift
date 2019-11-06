//
//  WebSiteCell.swift
//  Tok
//
//  Created by gaven on 2019/10/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class WebSiteCell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    
    var name: String? {
        didSet {
            nameLabel.text = name
        }
    }
    
    @objc
    @IBAction func copyAction() {
        if let name = name {
            UIPasteboard.general.string = name
            ProgressHUD.showTextHUD(withText: NSLocalizedString("The text has been copied to the clipboard", comment: ""), in: self.window)
        }
    }
}
