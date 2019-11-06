//
//  InsetTextLabel.swift
//  Tok
//
//  Created by Bryce on 2019/6/24.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class InsetTextLabel: UILabel {

    var contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6) {
        didSet {
            invertedContentInset = UIEdgeInsets(top: -contentInset.top,
                                                left: -contentInset.left,
                                                bottom: -contentInset.bottom,
                                                right: -contentInset.right)
            invalidateIntrinsicContentSize()
        }
    }
    
    private var invertedContentInset = UIEdgeInsets(top: -1, left: -6, bottom: -1, right: -6)
    
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let layoutBounds = bounds.inset(by: contentInset)
        let textRect = super.textRect(forBounds: layoutBounds, limitedToNumberOfLines: numberOfLines)
        return textRect.inset(by: invertedContentInset)
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInset))
    }
}
