//
//  SwitchCell.swift
//  FChat
//
//  Created by zhanghanbing on 2019/1/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift

class SwitchCell: UITableViewCell {

    var disposeBag = DisposeBag()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        return label
    }()
    
    lazy var switchButton: UISwitch = {
        let button = UISwitch()
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        selectionStyle = .none
        
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.centerY.equalToSuperview()
        }
        
        accessoryView = switchButton
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
}
