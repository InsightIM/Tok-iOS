//
//  OnboardingCoordinator.swift
//  Tok
//
//  Created by Bryce on 2019/2/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift

class OnboardingCoordinator: BaseCoordinator<Void> {
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        
        super.init()
    }
    
    override func start() -> Observable<Void> {
        return Observable.deferred {
            UserDefaultsManager().showOnboarding = false
            
            let viewController = OnboardingViewController()
            self.window.rootViewController = viewController
            self.window.makeKeyAndVisible()
            
            return viewController.welcomeButton.rx.tap.map { () }
        }
    }
}
