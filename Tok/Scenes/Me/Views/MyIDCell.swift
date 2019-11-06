//
//  MyIDCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Reusable

class MyIDCell: UITableViewCell, NibLoadable {

    var didClickCopy: ((String?) -> Void)?
    var didClickShare: (() -> Void)?
    
    @IBOutlet weak var titleLabel: UILabel! {
        didSet {
            titleLabel.text = NSLocalizedString("My Tok ID", comment: "")
        }
    }
    @IBOutlet weak var tokIDLabel: UILabel! {
        didSet {
            tokIDLabel.copyable = true
        }
    }
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var shareButton: UIButton! {
        didSet {
            shareButton.fcBorderStyle(title: NSLocalizedString("Share", comment: ""), color: UIColor("#007AFF"), bgColor: .white, borderWidth: 1)
        }
    }
    
    @IBAction func didCopy(_ sender: UIButton) {
        didClickCopy?(UserService.shared.toxMananger?.user.userAddress)
    }
    
    @IBAction func didShare(_ sender: UIButton) {
        didClickShare?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
