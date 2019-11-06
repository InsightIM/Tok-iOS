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
    
    func fcBorderStyle(title: String?, color: UIColor = .tokBlue, bgColor: UIColor = .white, borderWidth: CGFloat = 2) {
        if let title = title {
            self.setTitle(title, for: .normal)
        }
        self.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        self.setTitleColor(color, for: .normal)
        self.setTitleColor(color.withAlphaComponent(0.6), for: .highlighted)
        self.setBackgroundImage(bgColor.createImage(), for: .normal)
        self.setBackgroundImage(bgColor.withAlphaComponent(0.6).createImage(), for: .highlighted)
        self.layer.cornerRadius = 4.0
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = borderWidth
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

@objc extension UIButton {
    /// Enum to determine the title position with respect to the button image
    ///
    /// - top: title above button image
    /// - bottom: title below button image
    /// - left: title to the left of button image
    /// - right: title to the right of button image
    @objc enum Position: Int {
        case top, bottom, left, right
    }
    
    /// This method sets an image and title for a UIButton and
    ///   repositions the titlePosition with respect to the button image.
    ///
    /// - Parameters:
    ///   - image: Button image
    ///   - title: Button title
    ///   - titlePosition: UIViewContentModeTop, UIViewContentModeBottom, UIViewContentModeLeft or UIViewContentModeRight
    ///   - additionalSpacing: Spacing between image and title
    ///   - state: State to apply this behaviour
    @objc func set(image: UIImage?, title: String, imageSize: CGSize, titlePosition: Position, additionalSpacing: CGFloat, state: UIControl.State){
        imageView?.contentMode = .center
        setImage(image, for: state)
        setTitle(title, for: state)
        titleLabel?.contentMode = .center
        
        adjust(title: title as NSString, at: titlePosition, with: additionalSpacing, imageSize: imageSize)
    }
    
    // MARK: Private Methods
    
    @objc private func adjust(title: NSString, at position: Position, with spacing: CGFloat, imageSize: CGSize) {
        // Use predefined font, otherwise use the default
        let titleFont: UIFont = titleLabel?.font ?? UIFont()
        let titleSize: CGSize = title.size(withAttributes: [NSAttributedString.Key.font: titleFont])
        
        arrange(titleSize: titleSize, imageRect: imageSize, atPosition: position, withSpacing: spacing)
    }
    
    @objc private func arrange(titleSize: CGSize, imageRect: CGSize, atPosition position: Position, withSpacing spacing: CGFloat) {
        switch (position) {
        case .top:
            titleEdgeInsets = UIEdgeInsets(top: -(imageRect.height + titleSize.height + spacing), left: -(imageRect.width), bottom: 0, right: 0)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -titleSize.width)
            contentEdgeInsets = UIEdgeInsets(top: spacing / 2 + titleSize.height, left: -imageRect.width/2, bottom: 0, right: -imageRect.width/2)
        case .bottom:
            titleEdgeInsets = UIEdgeInsets(top: (imageRect.height + titleSize.height + spacing), left: -(imageRect.width), bottom: 0, right: 0)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -titleSize.width)
            contentEdgeInsets = UIEdgeInsets(top: 0, left: -imageRect.width/2, bottom: spacing / 2 + titleSize.height, right: -imageRect.width/2)
        case .left:
            titleEdgeInsets = UIEdgeInsets(top: 0, left: -(imageRect.width * 2), bottom: 0, right: 0)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -(titleSize.width * 2 + spacing))
            contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: spacing / 2)
        case .right:
            titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -spacing)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: spacing / 2)
        }
    }
}
