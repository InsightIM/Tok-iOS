//
//  InputCell.swift
//  Tok
//
//  Created by Bryce on 2018/7/22.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class InputCell: UITableViewCell {
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = UIColor.tokBlack
        return label
    }()
    
    lazy var rightTextField: UITextField = {
        let textField = UITextField()
        textField.adjustsFontSizeToFitWidth = true
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.textColor = UIColor.tokBlack
        textField.isSecureTextEntry = true
        return textField
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        selectionStyle = .none
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(10)
            make.width.equalTo(100)
            make.top.bottom.equalToSuperview()
        }
        
        contentView.addSubview(rightTextField)
        rightTextField.snp.makeConstraints { (make) in
            make.left.equalTo(nameLabel.snp.right).offset(8)
            make.right.equalTo(-10)
            make.top.bottom.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
