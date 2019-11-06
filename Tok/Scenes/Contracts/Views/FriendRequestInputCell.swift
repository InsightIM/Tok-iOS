//
//  FriendRequestInputCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class FriendRequestInputCell: UITableViewCell {
    lazy var nameField: UITextField = {
        let textField = UITextField()
        textField.textColor = UIColor.tokTitle4
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(nameField)
        nameField.snp.makeConstraints { (make) in
            make.edges.equalTo(UIEdgeInsets(top: 0, left: GroupedPadding, bottom: 0, right: GroupedPadding))
            make.height.equalTo(48).priorityHigh()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
