//
//  PinNumberView.swift
//  Tok
//
//  Created by lbowen on 2019/9/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

enum NumberViewState {
    case normal
    case highlight
}

class PinNumberView: UIView {
    
    private var text: String = ""
    private var state: NumberViewState = .normal

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        let cr = UIGraphicsGetCurrentContext()
        
        let lineWidth: CGFloat = 1.0
        let numberDiameter = min(rect.size.width, rect.size.height) - lineWidth * 2
        let numberX = (rect.size.width - numberDiameter) * 0.5
        let numberY = (rect.size.height - numberDiameter) * 0.5;
        let numberRect = CGRect(x: numberX, y: numberY, width: numberDiameter, height: numberDiameter);
        
        cr?.addEllipse(in: numberRect)
        cr?.setLineWidth(lineWidth)
        
        if state == .highlight {
            UIColor.init(white: 0.5, alpha: 1).set()
            cr?.fillPath()
        } else {
            UIColor(red: 133/255.0, green: 188/255.0, blue: 219/255.0, alpha: 1.0).set()
            cr?.fillPath()
        }
        
        let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        style.alignment = .center
        let attributeDic = [NSAttributedString.Key.font:UIFont.systemFont(ofSize: 30),NSAttributedString.Key.foregroundColor:UIColor.white,NSAttributedString.Key.paragraphStyle:style
        ]
        
        let textSize = (NSString(string: text).boundingRect(with: rect.size, options: .usesFontLeading, attributes: attributeDic, context: nil)).size
        let textW = textSize.width
        let textH = textSize.height
        let textX = (rect.size.width - textW) * 0.5
        let textY = (rect.size.height - textH) * 0.5
        let textRect = CGRect(x: textX, y: textY, width: textW, height: textH)
        
        NSString(string: text).draw(in: textRect, withAttributes: attributeDic)
    }
    
    var numberText: String {
        get {
            return text
        }
        set {
            text = newValue
            setNeedsDisplay()
        }
    }
    
    var viewState: NumberViewState {
        get {
            return state
        }
        set {
            state = newValue
            setNeedsDisplay()
        }
    }
}
