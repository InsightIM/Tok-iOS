//
//  PasscodeInfoView.swift
//  Tok
//
//  Created by lbowen on 2019/9/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class PasscodeInfoView: UIView {

    private var count: NSInteger = 0
    private var style: PassCodeStyle = .system
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        let cr = UIGraphicsGetCurrentContext()
        
        if style == .system {
            UIColor.gray.set()
        } else {
            UIColor.white.set()
        }
        
        let h = rect.size.height
        let w = rect.size.width
        
        let marginLR: CGFloat = 15.0
        let circleWH: CGFloat = 10.0
        let circleY = h > circleWH ? (h - circleWH) * 0.5 : 0
        
        let temp = w - circleWH * 4
        let marginLeft = (temp - marginLR * (4 - 1)) * 0.5
        
        let arr: [CGFloat] = [0, 1, 2, 3]
        for i in arr {
            
            let circleX = marginLeft + (circleWH + marginLR) * i
            cr?.addEllipse(in: .init(x: circleX, y: circleY, width: circleWH, height: circleWH))
            
            if i+1 <= CGFloat(infoCount) {
                cr?.fillPath()
            } else {
                cr?.strokePath()
            }
        }
    }
    
    var codeStyle: PassCodeStyle {
        get {
            return style
        }
        set {
            style = newValue
            setNeedsDisplay()
        }
    }
    
    var infoCount: NSInteger {
        get {
            return count
        }
        set {
            count = newValue
            setNeedsDisplay()
        }
    }
}
