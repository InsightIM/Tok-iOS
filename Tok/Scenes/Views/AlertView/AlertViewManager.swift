//
//  AlertViewManager.swift
//  Tok
//
//  Created by Bryce on 2019/1/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SwiftMessages
import RxSwift
import RxCocoa
import Action

class AlertViewManager {
    typealias Action = () -> Void
    
    static func showActionSheet(with actions: [(String, UIAlertAction.Style, Action?)]) {
        let view: AlertButtonView = try! SwiftMessages.viewFromNib()
        view.bounceAnimationOffset = 0
        var config = SwiftMessages.Config()
        config.presentationStyle = .bottom
        config.presentationContext = .window(windowLevel: .alert)
        config.duration = .forever
        config.dimMode = .gray(interactive: true)
        
        let buttons = actions
            .map { (title, style, action) -> UIButton in
                var button = UIButton()
                button.setSheetButtonStyle(title: title, style: style)
                button.addBottomLine()
                button.rx.action = CocoaAction {
                    action?()
                    SwiftMessages.hide()
                    return .empty()
                }
                return button
        }
        
        view.stackView.arrangedSubviews.forEach { subview in
            view.stackView.removeArrangedSubview(subview)
        }
        
        buttons.forEach { button in
            button.heightAnchor.constraint(equalToConstant: AlertViewConstants.height).isActive = true
            view.stackView.addArrangedSubview(button)
        }
        
        SwiftMessages.show(config: config, view: view)
    }
    
    static func showMessageSheet(with title: String, cancelTitle: String? = nil) {
        let view: AlertMessageView = try! SwiftMessages.viewFromNib()
        view.bounceAnimationOffset = 0
        var config = SwiftMessages.Config()
        config.presentationStyle = .bottom
        config.presentationContext = .window(windowLevel: .alert)
        config.duration = .forever
        config.dimMode = .gray(interactive: true)
        
        view.messageLabel.text = title
        
        if let cancelTitle = cancelTitle {
            view.cancelButton.setTitle(cancelTitle, for: .normal)
        }
        
        view.stackView.arrangedSubviews.forEach { subview in
            view.stackView.removeArrangedSubview(subview)
        }
        
        SwiftMessages.show(config: config, view: view)
    }
    
    static func showMessageSheet(with title: String, interactive: Bool = true, actions: [(String, UIAlertAction.Style, Action?)] = [], cancelTitle: String? = nil,  customCancelAction: Action? = nil) {
        let view: AlertMessageView = try! SwiftMessages.viewFromNib()
        view.bounceAnimationOffset = 0
        view.customCancelAction = customCancelAction
        var config = SwiftMessages.Config()
        config.presentationStyle = .bottom
        config.presentationContext = .window(windowLevel: .alert)
        config.duration = .forever
        config.dimMode = .gray(interactive: interactive)
        
        view.messageLabel.text = title
        
        let buttons = actions
            .map { (title, style, action) -> UIButton in
                var button = UIButton()
                button.setSheetButtonStyle(title: title, style: style)
                button.addBottomLine()
                button.rx.action = CocoaAction {
                    action?()
                    SwiftMessages.hide()
                    return .empty()
                }
                return button
        }
        
        view.stackView.arrangedSubviews.forEach { subview in
            view.stackView.removeArrangedSubview(subview)
        }
        
        buttons.forEach { button in
            button.heightAnchor.constraint(equalToConstant: AlertViewConstants.height).isActive = true
            view.stackView.addArrangedSubview(button)
        }
        
        if let cancelTitle = cancelTitle {
            view.cancelButton.setTitle(cancelTitle, for: .normal)
        }
        
        SwiftMessages.show(config: config, view: view)
    }
    
    static func showActionSheet(customView: UIView, actions: [(String, UIAlertAction.Style, Action?)]) {
        let view: AlertButtonView = try! SwiftMessages.viewFromNib()
        view.bounceAnimationOffset = 0
        var config = SwiftMessages.Config()
        config.presentationStyle = .bottom
        config.presentationContext = .window(windowLevel: .alert)
        config.duration = .forever
        config.dimMode = .gray(interactive: true)
        
        let buttons = actions
            .map { (title, style, action) -> UIButton in
                var button = UIButton()
                button.setSheetButtonStyle(title: title, style: style)
                button.setTitleColor(.tokLink, for: .normal)
                button.addBottomLine()
                button.rx.action = CocoaAction {
                    action?()
                    SwiftMessages.hide()
                    return .empty()
                }
                return button
        }
        
        view.stackView.arrangedSubviews.forEach { subview in
            view.stackView.removeArrangedSubview(subview)
        }
        
        view.stackView.addArrangedSubview(customView)
        buttons.forEach { button in
            button.heightAnchor.constraint(equalToConstant: AlertViewConstants.height).isActive = true
            view.stackView.addArrangedSubview(button)
        }
        
        SwiftMessages.show(config: config, view: view)
    }
}

extension UIButton {
    func setSheetButtonStyle(title: String, style: UIAlertAction.Style) {
        setTitle(title, for: .normal)
        
        switch style {
        case .destructive:
            setTitleColor(.tokNotice, for: .normal)
        default:
            setTitleColor(UIColor("#171F24"), for: .normal)
        }
        
        ts_setBackgroundColor(.white, forState: .normal)
        ts_setBackgroundColor(.tokLine, forState: .highlighted)
        
        titleLabel?.font = UIFont.systemFont(ofSize: 17)
    }
}

struct AlertViewConstants {
    static let height: CGFloat = 55
}
