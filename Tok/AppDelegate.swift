//
//  AppDelegate.swift
//  Tok
//
//  Created by Bryce on 2018/6/6.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import UserNotifications
import RxSwift
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    private var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    
    private let disposeBag = DisposeBag()
    
    private var appCoordinator: AppCoordinator!
    
    private var lockView: PasscodeLockView?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        setupAppAppearence()
        
        appCoordinator = AppCoordinator(window: window!)
        appCoordinator.start()
            .subscribe()
            .disposed(by: disposeBag)

        if UserDefaultsManager().CrashEnabled {
            FirebaseApp.configure()
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundTask = UIApplication.shared.beginBackgroundTask (expirationHandler: { [unowned self] in
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        })
        
        addLockView()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        showLockView()
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        handleInboxURL(url)
        
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        handleInboxURL(url)
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        AudioManager.shared.stop(deactivateAudioSession: true)
    }
}

extension AppDelegate {

    private func addLockView() {

        lockView?.removeFromSuperview()

        let lockV = PasscodeLockView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
        lockView = lockV
        UIApplication.shared.keyWindow?.addSubview(lockV)
    }

    private func showLockView() {

        if UserDefaultsManager().pinEnabled == true {
            lockView?.showFingerprintTouch()
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func registerUserNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge], completionHandler: { (_, _) in })
        center.delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UserService.shared.uploadPushManager.deviceToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//        if let newNodes = userInfo["nodes"] as? String {
//            ToxNodes.store(jsonString: newNodes)
//        } else
        if application.applicationState == .background {
            UIApplication.shared.applicationIconBadgeNumber += 1
        }
        completionHandler(.newData)
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension AppDelegate {
    func setupAppAppearence() {
        UINavigationBar.appearance().barTintColor = UIColor.white
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().tintColor = UIColor.tokBlack
        
        let shadowImage = UIColor.clear.creatImageWithSize(size: CGSize(width: UIScreen.main.bounds.width, height: 1.0 / UIScreen.main.scale))
        UINavigationBar.appearance().shadowImage = shadowImage
        
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .medium),
                                                            NSAttributedString.Key.foregroundColor: UIColor.tokBlack]
        
        UITableViewHeaderFooterView.appearance().tintColor = UIColor.tokBackgroundColor
    }
}

extension AppDelegate {
    
    func handleInboxURL(_ url: URL) {
        let fileName = url.lastPathComponent
        let isToxFile = url.isToxURL()
        guard isToxFile else {
            AlertViewManager.showMessageSheet(with: NSLocalizedString("This is not a tok profile", comment: ""), cancelTitle: NSLocalizedString("OK", comment: ""))
            
            return
        }
        
        if let homeViewController = window?.rootViewController as? HomeViewController {
            let chat = homeViewController.viewControllers?.first as? UINavigationController
            chat?.popToRootViewController(animated: false)
        } else {
            let welcome = window?.rootViewController as? UINavigationController
            welcome?.popToRootViewController(animated: false)
        }
        
        let importAction: AlertViewManager.Action = { [unowned self] in
            UserService.shared.logout()
            
            let nav = self.window?.rootViewController as? UINavigationController
            let vc = RegisterViewController()
            vc.title = NSLocalizedString("Import Account", comment: "")
            vc.copyURL = url
            nav?.pushViewController(vc, animated: false)
        }
        
        AlertViewManager.showMessageSheet(with: fileName, actions: [
            (NSLocalizedString("Import Profile", comment: ""), .default, importAction)
            ])
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIBackgroundTaskIdentifier(_ input: Int) -> UIBackgroundTaskIdentifier {
	return UIBackgroundTaskIdentifier(rawValue: input)
}

//public func print<T>(file: String = #file, function: String = #function, line: Int = #line, _ message: T, color: UIColor = .white) {
//    #if DEBUG
//    swiftLog(file, function, line, message, color, false)
//    #endif
//}
