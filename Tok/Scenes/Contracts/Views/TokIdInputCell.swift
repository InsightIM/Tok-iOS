//
//  TokIdInputCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class TokIdInputCell: UITableViewCell {
    
    lazy var textView: UITextView = {
        let textView = RSKPlaceholderTextView()
        textView.placeholder = NSLocalizedString("Please paste your friend's Tok ID", comment: "") as NSString
        textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.tokBlack
        textView.backgroundColor = .clear
        textView.returnKeyType = .done
        return textView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(textView)
        textView.snp.makeConstraints { (make) in
            make.edges.equalTo(UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20))
            make.height.equalTo(80).priorityHigh()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
