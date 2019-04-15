//
//  UIViewExtension.swift
//  Tok
//
//  Created by Bryce on 2018/6/26.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SnapKit

extension UIView {
    var safeArea: ConstraintBasicAttributesDSL {
        #if swift(>=3.2)
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp
        }
        return self.snp
        #else
        return self.snp
        #endif
    }
}

extension UIView {
    
    func screenshot(frame: CGRect? = nil) -> UIImage? {
        
        if let scrollView = self as? UIScrollView {
            
            return scrollViewScreenShot(scrollView, frame: frame)
            
        } else if let webView = self as? UIWebView {
            
            let scrollView = webView.scrollView
            
            return scrollViewScreenShot(scrollView, frame: frame)
            
        } else {
            
            let shotFrame: CGRect = (frame == nil) ? self.bounds : frame!
            
            UIGraphicsBeginImageContextWithOptions(shotFrame.size, true, 0)
            
            guard let currentContext = UIGraphicsGetCurrentContext() else { return nil }
            
            currentContext.translateBy(x: -shotFrame.origin.x, y: -shotFrame.origin.y)
            
            let path = UIBezierPath(rect: shotFrame)
            
            path.addClip()
            
            layer.render(in: currentContext)
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            
            UIGraphicsEndImageContext()
            
            return image
        }
    }
    
    private func scrollViewScreenShot(_ scrollView: UIScrollView, frame: CGRect?) -> UIImage? {
        
        let shotFrame: CGRect = (frame == nil) ? CGRect(origin: CGPoint(), size: scrollView.contentSize) : frame!
        
        UIGraphicsBeginImageContextWithOptions(shotFrame.size, false, 0)
        
        let savedContentOffset = scrollView.contentOffset
        
        let savedFrame = scrollView.frame
        
        scrollView.contentOffset = CGPoint()
        
        scrollView.frame = CGRect(origin: CGPoint(), size: scrollView.contentSize)
        
        guard let currentContext = UIGraphicsGetCurrentContext() else { return nil }
        
        currentContext.translateBy(x: -shotFrame.origin.x, y: -shotFrame.origin.y)
        
        let path = UIBezierPath(rect: shotFrame)
        
        path.addClip()
        
        scrollView.layer.render(in: currentContext)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        scrollView.contentOffset = savedContentOffset
        
        scrollView.frame = savedFrame
        
        return image
    }
}

extension UIView {
    var width: CGFloat {
        get { return self.frame.size.width }
        set {
            var frame = self.frame
            frame.size.width = newValue
            self.frame = frame
        }
    }
    
    var height: CGFloat {
        get { return self.frame.size.height }
        set {
            var frame = self.frame
            frame.size.height = newValue
            self.frame = frame
        }
    }
    
    var size: CGSize  {
        get { return self.frame.size }
        set {
            var frame = self.frame
            frame.size = newValue
            self.frame = frame
        }
    }
    
    var origin: CGPoint {
        get { return self.frame.origin }
        set {
            var frame = self.frame
            frame.origin = newValue
            self.frame = frame
        }
    }
    
    var x: CGFloat {
        get { return self.frame.origin.x }
        set {
            var frame = self.frame
            frame.origin.x = newValue
            self.frame = frame
        }
    }
    var y: CGFloat {
        get { return self.frame.origin.y }
        set {
            var frame = self.frame
            frame.origin.y = newValue
            self.frame = frame
        }
    }
    
    var centerX: CGFloat {
        get { return self.center.x }
        set {
            self.center = CGPoint(x: newValue, y: self.center.y)
        }
    }
    
    var centerY: CGFloat {
        get { return self.center.y }
        set {
            self.center = CGPoint(x: self.center.x, y: newValue)
        }
    }
    
    var top : CGFloat {
        get { return self.frame.origin.y }
        set {
            var frame = self.frame
            frame.origin.y = newValue
            self.frame = frame
        }
    }
    
    var bottom : CGFloat {
        get { return frame.origin.y + frame.size.height }
        set {
            var frame = self.frame
            frame.origin.y = newValue - self.frame.size.height
            self.frame = frame
        }
    }
    
    var right : CGFloat {
        get { return self.frame.origin.x + self.frame.size.width }
        set {
            var frame = self.frame
            frame.origin.x = newValue - self.frame.size.width
            self.frame = frame
        }
    }
    
    var left : CGFloat {
        get { return self.frame.origin.x }
        set {
            var frame = self.frame
            frame.origin.x  = newValue
            self.frame = frame
        }
    }
}

extension UIView {
    /**
     Init from nib
     Notice: The nib file name is the same as the calss name
     
     - returns: UINib
     */
    class func ts_Nib() -> UINib {
        let hasNib: Bool = Bundle.main.path(forResource: self.ts_className, ofType: "nib") != nil
        guard hasNib else {
            assert(!hasNib, "Nib is not exist")
            return UINib()
        }
        return UINib(nibName: self.ts_className, bundle:nil)
    }
    
    /**
     Init from nib and get the view
     Notice: The nib file name is the same as the calss name
     
     Demo： UIView.ts_viewFromNib(TSCustomView)
     
     - parameter aClass: your class
     
     - returns: Your class's view
     */
    class func ts_viewFromNib<T>(_ aClass: T.Type) -> T {
        let name = String(describing: aClass)
        if Bundle.main.path(forResource: name, ofType: "nib") != nil {
            return UINib(nibName: name, bundle:nil).instantiate(withOwner: nil, options: nil)[0] as! T
        } else {
            fatalError("\(String(describing: aClass)) nib is not exist")
        }
    }
    
    /**
     All subviews of the UIView
     
     - returns: A group of UIView
     */
    func ts_allSubviews() -> [UIView] {
        var stack = [self]
        var views = [UIView]()
        while !stack.isEmpty {
            let subviews = stack[0].subviews as [UIView]
            views += subviews
            stack += subviews
            stack.remove(at: 0)
        }
        return views
    }
    
    /**
     Take snap shot
     
     - returns: UIImage
     */
    func ts_takeSnapshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    /// Check the view is visible
    @available(iOS 8.0, *)
    var ts_visible: Bool {
        get {
            if self.window == nil || self.isHidden || self.alpha == 0 {
                return true
            }
            
            let viewRect = self.convert(self.bounds, to: nil)
            guard let app = UIApplication.ts_sharedApplication() else {
                return false
            }
            guard let window = app.keyWindow else {
                return true
            }
            return viewRect.intersects(window.bounds) == false
        }
    }
}

extension UIView {
    func addBottomLine() {
        let view = UIView()
        view.backgroundColor = .tokLine
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
}

fileprivate let kShapeDashed : String = "kShapeDashed"

extension UIView {
    
    func removeDashedBorder(_ view: UIView) {
        view.layer.sublayers?.forEach {
            if kShapeDashed == $0.name {
                $0.removeFromSuperlayer()
            }
        }
    }
    
    func addDashedBorder(width: CGFloat? = nil, height: CGFloat? = nil, lineWidth: CGFloat = 2, lineDashPattern:[NSNumber]? = [6,3], strokeColor: UIColor = UIColor.tokLine, fillColor: UIColor = UIColor.clear) {
        
        var fWidth: CGFloat? = width
        var fHeight: CGFloat? = height
        
        if fWidth == nil {
            fWidth = self.frame.width
        }
        
        if fHeight == nil {
            fHeight = self.frame.height
        }
        
        let shapeLayer:CAShapeLayer = CAShapeLayer()
        
        let shapeRect = CGRect(x: 0, y: 0, width: fWidth!, height: fHeight!)
        
        shapeLayer.bounds = shapeRect
        shapeLayer.position = CGPoint(x: fWidth!/2, y: fHeight!/2)
        shapeLayer.fillColor = fillColor.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineJoin = CAShapeLayerLineJoin.round
        shapeLayer.lineDashPattern = lineDashPattern
        shapeLayer.name = kShapeDashed
        shapeLayer.path = UIBezierPath(roundedRect: shapeRect, cornerRadius: 5).cgPath
        
        self.layer.addSublayer(shapeLayer)
    }
}

