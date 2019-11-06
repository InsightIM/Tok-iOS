//
//  LogoCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/10.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Reusable

class LogoCell: UITableViewCell, NibLoadable {

    @IBOutlet weak var sloganLabel: UILabel! {
        didSet {
            sloganLabel.text = NSLocalizedString("Make the world connect freely!", comment: "")
        }
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
