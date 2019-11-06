//
//  DigitalCurrencyCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/10.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class DigitalCurrencyCell: UITableViewCell {
    
    var didCopy: ((String?)-> Void)?

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var copyButton: UIButton!
    @IBAction func didCopy(_ sender: UIButton) {
        didCopy?(addressLabel.text)
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
