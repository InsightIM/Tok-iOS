//
//  SettingsCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/22.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class SettingsCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        textLabel?.font = UIFont.systemFont(ofSize: 16)
        textLabel?.textColor = UIColor.tokTitle4
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
