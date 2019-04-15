//
//  NotificationBannerExtension.swift
//  Tok
//
//  Created by Bryce on 2018/6/25.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import SwiftMessages

class NotificationBannerManager {
    static let shared = NotificationBannerManager()
    
    private let notificationMessages = SwiftMessages()
    
    func showInStatusBar(_ title: String) {
        let banner = MessageView.viewFromNib(layout: .statusLine)
        banner.configureTheme(backgroundColor: .tokBlue, foregroundColor: .white, iconImage: nil, iconText: nil)
        banner.configureContent(body: title)
        banner.titleLabel?.isHidden = true
        
        var config = SwiftMessages.defaultConfig
        config.duration = .forever
        config.presentationContext = .window(windowLevel: UIWindow.Level.statusBar)
        notificationMessages.show(config: config, view: banner)
    }
    
    func hideInStatusBar() {
        notificationMessages.hide()
    }
}
