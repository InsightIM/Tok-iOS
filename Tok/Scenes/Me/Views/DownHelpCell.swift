//
//  DownHelpCell.swift
//  Tok
//
//  Created by gaven on 2019/10/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class DownHelpCell: UITableViewCell {
    
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    
    var account: VersionInfo.AppleAccount? {
        didSet {
            if let account = account {
                emailLabel.text = account.email
                passwordLabel.text = account.password
            }
        }
    }
    
    @objc
    @IBAction func copyAction() {
        if let email = account?.email {
            UIPasteboard.general.string = email
            ProgressHUD.showTextHUD(withText: NSLocalizedString("The text has been copied to the clipboard", comment: ""), in: self.window)
        }
    }
}
