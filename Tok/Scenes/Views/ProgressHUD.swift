//
//  ProgressHUD.swift
//  Tok
//
//  Created by Bryce on 2018/6/30.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SnapKit

class ProgressHUD: MBProgressHUD {
    
    fileprivate var containerView: UIView? {
        willSet {
            if let oldValue = containerView, oldValue != newValue {
                oldValue.removeFromSuperview()
            }
        }
    }
    
    class func updateLoading(_ isLoading: Bool, in view: UIView?) {
        if isLoading {
            self.showLoadingHUD(in: view)
        } else {
            self.hideLoadingHUD(in: view)
        }
    }
    
    class func showLoadingHUD(in view: UIView?) {
        guard let view = view else {
            return
        }
        
        ProgressHUD.showAdded(to: view, animated: true)
    }
    
    class func hideLoadingHUD(in view: UIView?) {
        guard let view = view else {
            return
        }
        self.hide(for: view, animated: false)
    }
    
    class func showLoadingHUDInWindow() {
        let view = UIApplication.shared.keyWindow
        if let view = view {
            self.showLoadingHUD(in: view)
        }
    }
    
    class func hideLoadingHUDInWindow() {
        let view = UIApplication.shared.keyWindow
        if let view = view {
            self.hideLoadingHUD(in: view)
        }
    }
}

extension MBProgressHUD {
    class func showTextHUD(withText text: String?, in view: UIView?, afterDelay second: TimeInterval = 1.5, completion: (() -> Void)? = nil) {
        guard let text = text, let view = view else {
            return
        }
        
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .text
        hud.offset = CGPoint(x: 0, y: 0)
        hud.bezelView.color = UIColor.black
        hud.bezelView.layer.cornerRadius = 12.0
        hud.bezelView.layer.masksToBounds = true
        hud.detailsLabel.text = text
        hud.detailsLabel.textColor = UIColor.white
        hud.detailsLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        hud.margin = 10
        hud.completionBlock = {
            completion?()
        }
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: true, afterDelay: second)
    }
}
