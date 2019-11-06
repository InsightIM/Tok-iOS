//
//  WordsCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class WordsCell: UITableViewCell {
    
    lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.tokTitle4
        label.numberOfLines = 0
        return label
    }()
    
    lazy var selectedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Selected")
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        layer.masksToBounds = true
        layer.cornerRadius = 6
        selectionStyle = .none
        
        contentView.addSubview(contentLabel)
        contentView.addSubview(selectedImageView)
        
        contentLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(14)
            make.top.equalTo(14)
            make.bottom.equalTo(-14)
        }
        selectedImageView.snp.makeConstraints { (make) in
            make.size.equalTo(20)
            make.bottom.equalTo(-14)
            make.trailing.equalTo(-8)
            make.leading.equalTo(contentLabel.snp.trailing).offset(8)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectedImageView.isHidden = !selected
    }
}
