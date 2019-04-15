//
//  UILabelExtension.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

extension UILabel {
    
    private struct AssociatedKeys {
        static var copyable = "copyable"
        static var longPressGestureRecognizer = "longPressGestureRecognizer"
    }
    
    @IBInspectable public var copyable: Bool {
        get {
            guard let number = objc_getAssociatedObject(self, &AssociatedKeys.copyable) as? NSNumber else {
                return true
            }
            
            return number.boolValue
        }
        
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.copyable, NSNumber(value: newValue),
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            newValue ? enableCopying() : disableCopying()
        }
    }
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.longPressGestureRecognizer) as?
            UILongPressGestureRecognizer
        }
        
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.longPressGestureRecognizer, newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func enableCopying() {
        isUserInteractionEnabled = true
        
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(showCopyMenu))
        addGestureRecognizer(longPressGestureRecognizer!)
    }
    
    private func disableCopying() {
        isUserInteractionEnabled = false
        
        if let gestureRecognizer = longPressGestureRecognizer {
            removeGestureRecognizer(gestureRecognizer)
            longPressGestureRecognizer = nil
        }
    }
    
    @objc private func showCopyMenu() {
        let copyMenu = UIMenuController.shared
        
        guard !copyMenu.isMenuVisible else { return }
        
        becomeFirstResponder()
        
        copyMenu.setTargetRect(bounds, in: self)
        copyMenu.setMenuVisible(true, animated: true)
    }
    
    override open var canBecomeFirstResponder : Bool {
        return copyable
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard copyable else { return false }
        
        if action == #selector(copy(_:)) {
            return true
        }
        
        return super.canPerformAction(action, withSender: sender)
    }
    
    override open func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
    }
    
}
