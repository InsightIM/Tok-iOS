//
//  LinkCell.swift
//  Tok
//
//  Created by Bryce on 2019/10/5.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class LinkCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        textLabel?.font = UIFont.systemFont(ofSize: 16)
        textLabel?.textColor = UIColor.tokLink
        textLabel?.text = NSLocalizedString("Share", comment: "")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
