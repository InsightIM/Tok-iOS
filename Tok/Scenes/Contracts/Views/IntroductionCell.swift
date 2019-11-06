//
//  IntroductionCell.swift
//  Tok
//
//  Created by Bryce on 2019/4/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class IntroductionCell: UITableViewCell {

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = UIColor.tokBlack
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor("#333333")
        return label
    }()
    
    lazy var moreButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("More", comment: ""), color: UIColor("#DEDEDE"), titleColor: UIColor("#333333"), cornerRadius: 12, titleFontSize: 14)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        translatesAutoresizingMaskIntoConstraints = false
        
        selectionStyle = .none
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.top.equalTo(12)
            make.right.equalTo(-20)
        }
        
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { (make) in
            make.left.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
        }
        
        contentView.addSubview(moreButton)
        moreButton.snp.makeConstraints { (make) in
            make.top.equalTo(detailLabel.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(-12)
            make.height.equalTo(24)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
