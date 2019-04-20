//
//  UIButtonExtension.swift
//  Tok
//
//  Created by Bryce on 2018/6/26.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

extension UIButton {
    
    func fcStyle(title: String?, color: UIColor = .tokBlue, titleColor: UIColor = .white, cornerRadius: CGFloat = 4.0, titleFontSize: CGFloat = 17) {
        if let title = title {
            self.setTitle(title, for: .normal)
        }
        self.titleLabel?.font = UIFont.systemFont(ofSize: titleFontSize)
        self.setTitleColor(titleColor, for: .normal)
        self.setBackgroundImage(color.createImage(), for: .normal)
        self.setBackgroundImage(color.withAlphaComponent(0.6).createImage(), for: .highlighted)
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = true
    }
    
    func fcBorderStyle(title: String?, color: UIColor = .tokBlue, bgColor: UIColor = .white) {
        if let title = title {
            self.setTitle(title, for: .normal)
        }
        self.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        self.setTitleColor(color, for: .normal)
        self.setBackgroundImage(bgColor.createImage(), for: .normal)
        self.layer.cornerRadius = 4.0
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = 2.0
        self.layer.masksToBounds = true
    }
    
    func yellowStyle(title: String?) {
        self.yellowWithoutBorderStyle(title: title)
        self.layer.cornerRadius = 12.0
        self.layer.masksToBounds = true
    }
    
    func yellowWithoutBorderStyle(title: String?) {
        if let title = title {
            self.setTitle(title, for: .normal)
        }
        self.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        self.setTitleColor(.tokBlack, for: .normal)
        self.setTitleColor(UIColor(red: 132/255.0, green: 132.0/255.0, blue: 132/255.0, alpha: 1), for: .disabled)
        self.setBackgroundImage(UIColor(red: 1, green: 227.0/255, blue: 0, alpha: 1).createImage(), for: .normal)
        self.setBackgroundImage(UIColor(red: 254/255.0, green: 216.0/255, blue: 1/255.0, alpha: 1).createImage(), for: .highlighted)
        self.setBackgroundImage(UIColor(red: 232/255.0, green: 232.0/255.0, blue: 232/255.0, alpha: 1).createImage(), for: .disabled)
    }
}

extension UIButton {
    /**
     Set UIButton's backgroundColor with a UIImage
     
     - parameter color:    color
     - parameter forState: UIControlState
     */
    public func ts_setBackgroundColor(_ color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIGraphicsGetCurrentContext()?.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let theImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.setBackgroundImage(theImage, for: forState)
    }
}
