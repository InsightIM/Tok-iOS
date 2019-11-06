//
//  PoetryView.swift
//  Tok
//
//  Created by Bryce on 2019/6/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class PoetryView: UIView {
    let poetry: [String]
    var contentHeight: CGFloat = 0
    init() {
        
        let originText = NSLocalizedString("NeverlandWelcome", comment: "")
        poetry = originText.components(separatedBy: "\n")
        
        super.init(frame: CGRect.zero)
        
        var y: CGFloat = 0
        for (_, text) in poetry.enumerated() {
            let label = UILabel()
            label.text = text
            label.textColor = UIColor.tokDarkBlue
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 13)
            
            let height = text.height(withConstrainedWidth: UIScreen.main.bounds.width, font: label.font)
            label.frame = CGRect(x: 0, y: y, width: UIScreen.main.bounds.width, height: height)
            self.addSubview(label)
            
            y += (height + 15)
        }
        contentHeight = y
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: contentHeight)
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return ceil(boundingBox.height)
    }
    
    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return ceil(boundingBox.width)
    }
}
