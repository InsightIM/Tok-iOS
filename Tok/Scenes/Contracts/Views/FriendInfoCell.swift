//
//  FriendInfoCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/10.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class FriendInfoCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        selectionStyle = .none
        
        textLabel?.numberOfLines = 0
        textLabel?.textColor = .tokBlack
        textLabel?.font = UIFont.systemFont(ofSize: 16)
        textLabel?.copyable = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
