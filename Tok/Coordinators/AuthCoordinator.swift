//
//  AuthCoordinator.swift
//  Tok
//
//  Created by Bryce on 2018/11/20.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

class AuthCoordinator: BaseCoordinator<Void> {
    
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    override func start() -> Observable<Void> {
        window.rootViewController = UINavigationController(rootViewController: WelcomeViewController())
        window.makeKeyAndVisible()
        
        return UserService.shared.didLogin.take(1)
    }
}
