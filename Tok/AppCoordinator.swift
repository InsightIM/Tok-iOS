//
//  AppCoordinator.swift
//  Tok
//
//  Created by Bryce on 2018/6/23.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

fileprivate enum LaunchInstructor {
    case auth, home, onboarding
    
    static func configure(isAutorized: Bool, showOnboarding: Bool) -> LaunchInstructor {
        switch (isAutorized, showOnboarding) {
        case (_, true):
            return .onboarding
        case (true, _):
            return .home
        case (false, _):
            return .auth
        }
    }
}

class AppCoordinator: BaseCoordinator<Void> {
    
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    override func start() -> Observable<Void> {
        reactiveFlow()
        
        return .never()
    }
}

fileprivate extension AppCoordinator {
    
    func reactiveFlow() {
        if window.rootViewController == nil {
            let launchScreen = UIStoryboard(name: "LaunchScreen", bundle: nil)
            window.rootViewController = launchScreen.instantiateInitialViewController()
        }
        window.makeKeyAndVisible()
        
        UserService.shared.tryLogin()
            .flatMapLatest { [unowned self] manager -> Observable<Void> in
                let isAutorized = manager != nil
                let showOnboarding = UserDefaultsManager().showOnboarding
                let launchInstructor = LaunchInstructor.configure(isAutorized: isAutorized, showOnboarding: showOnboarding)
                
                var runningFlow: Observable<Void>
                switch launchInstructor {
                case .auth: runningFlow = self.runAuthFlow()
                case .home:
                    runningFlow = self.runMainFlow(manager: manager!)
                    UIApplication.appDelegate.registerUserNotification()
                case .onboarding: runningFlow = self.runOnboardingFlow()
                }
                
                return runningFlow
            }
            .subscribe(onNext: { [unowned self] _ in
                self.reactiveFlow()
            })
            .disposed(by: disposeBag)
    }
    
    func runAuthFlow() -> Observable<Void> {
        let authCoordinator = AuthCoordinator(window: window)
        return coordinate(to: authCoordinator)
    }
    
    func runMainFlow(manager: OCTManager) -> Observable<Void> {
        let homeCoordinator = HomeCoordinator(window: window, manager: manager)
        return coordinate(to: homeCoordinator)
    }
    
    func runOnboardingFlow() -> Observable<Void> {
        let onboardingCoordinator = OnboardingCoordinator(window: window)
        return coordinate(to: onboardingCoordinator)
    }
}
