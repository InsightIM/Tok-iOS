//
//  GroupNameInputCell.swift
//  FChat
//
//  Created by zhanghanbing on 2018/12/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class GroupNameInputCell: UITableViewCell {
    
    lazy var nameField: UITextField = {
        let textField = UITextField()
        textField.placeholder = NSLocalizedString("Please enter group name", comment: "")
        textField.textColor = UIColor.tokTitle4
        textField.font = UIFont.systemFont(ofSize: 16)
        
        return textField
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(nameField)
        nameField.snp.makeConstraints { (make) in
            make.edges.equalTo(UIEdgeInsets(top: 0, left: GroupedPadding, bottom: 0, right: GroupedPadding))
            make.height.equalTo(56)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
