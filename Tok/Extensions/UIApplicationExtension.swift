//
//  UIApplicationExtension.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

extension UIApplication {
    /// Avoid the error: [UIApplication sharedApplication] is unavailable in xxx extension
    ///
    /// - returns: UIApplication?
    public class func ts_sharedApplication() ->  UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: selector) else { return nil }
        return UIApplication.perform(selector).takeUnretainedValue() as? UIApplication
    }
    
    ///Get screen orientation
    public class var ts_screenOrientation: UIInterfaceOrientation? {
        guard let app = self.ts_sharedApplication() else {
            return nil
        }
        return app.statusBarOrientation
    }
    
    ///Get status bar's height
    @available(iOS 8.0, *)
    public class var ts_screenStatusBarHeight: CGFloat {
        guard let app = UIApplication.ts_sharedApplication() else {
            return 0
        }
        return app.statusBarFrame.height
    }
    
    /**
     Run a block in background after app resigns activity
     
     - parameter closure:           The closure
     - parameter expirationHandler: The expiration handler
     */
    public func ts_runIntoBackground(_ closure: @escaping () -> Void, expirationHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let taskID: UIBackgroundTaskIdentifier
            if let expirationHandler = expirationHandler {
                taskID = self.beginBackgroundTask(expirationHandler: expirationHandler)
            } else {
                taskID = self.beginBackgroundTask(expirationHandler: { })
            }
            closure()
            self.endBackgroundTask(taskID)
        }
    }
}

extension UIApplication {
    
    static var widthOfSafeArea: CGFloat {
        guard let rootView = UIApplication.shared.keyWindow else { return 0 }
        
        if #available(iOS 11.0, *) {
            
            let leftInset = rootView.safeAreaInsets.left
            
            let rightInset = rootView.safeAreaInsets.right
            
            return rootView.bounds.width - leftInset - rightInset
        } else {
            return rootView.bounds.width
        }
    }
    
    static var heightOfSafeArea: CGFloat {
        guard let rootView = UIApplication.shared.keyWindow else { return 0 }
        
        if #available(iOS 11.0, *) {
            
            let topInset = rootView.safeAreaInsets.top
            
            let bottomInset = rootView.safeAreaInsets.bottom
            
            return rootView.bounds.height - topInset - bottomInset
            
        } else {
            
            return rootView.bounds.height
            
        }
    }
    
    static var safeAreaInsets: UIEdgeInsets {
        guard let rootView = UIApplication.shared.keyWindow else { return UIEdgeInsets.zero }
        
        if #available(iOS 11.0, *) {
            
            return rootView.safeAreaInsets
            
        } else {
            
            return UIEdgeInsets.zero
            
        }
    }
    
}

extension UIApplication {
    
    static var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    static func rootNavigationController() -> UINavigationController? {
        let tabbar = UIApplication.shared.keyWindow?.rootViewController as? UITabBarController
        return tabbar?.selectedViewController as? UINavigationController
    }
    
    static func currentActivity() -> UIViewController? {
        return rootNavigationController()?.visibleViewController
    }
}
