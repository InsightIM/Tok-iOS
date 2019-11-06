//
//  AboutItemCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/10.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Reusable

class AboutItemCell: UITableViewCell, NibLoadable {

    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    @IBOutlet weak var versionView: UIView!
    @IBOutlet weak var versionLabel: UILabel!
    
    var version: String? {
        didSet {
            versionView.isHidden = (version == nil)
            versionLabel.text = version
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
}
