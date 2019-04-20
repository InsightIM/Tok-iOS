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
#if DEBUG
import CocoaDebug
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    private var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    
    private let disposeBag = DisposeBag()
    
    private var appCoordinator: AppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor.white
        
        setupAppAppearence()
        
        appCoordinator = AppCoordinator(window: window!)
        appCoordinator.start()
            .subscribe()
            .disposed(by: disposeBag)
        
        #if DEBUG
        CocoaDebug.enable()
        #endif

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundTask = UIApplication.shared.beginBackgroundTask (expirationHandler: { [unowned self] in
            UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(self.backgroundTask.rawValue))
            self.backgroundTask = UIBackgroundTaskIdentifier.invalid
        })
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
        removeBlurView()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        FCAudioPlayer.shared().stop(withAudioSessionDeactivated: true)
        
        if let screenSnapshot = UIViewController.screenSnapshot(),
           let image = screenSnapshot.blurryImage(withOptions: BlurryOptions.pro, overlayColor: nil, blurRadius: 5) {
            let imageView = UIImageView(frame: UIScreen.main.bounds)
            imageView.contentMode = .scaleAspectFill
            imageView.image = image
            imageView.tag = 1000001
            UIApplication.shared.keyWindow?.addSubview(imageView)
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
        
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
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
    func removeBlurView() {
        let blurImageView = UIApplication.shared.keyWindow?.viewWithTag(1000001)
        blurImageView?.removeFromSuperview()
    }
    
    func setupAppAppearence() {
        UINavigationBar.appearance().barTintColor = UIColor.white
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().tintColor = UIColor.tokBlack
        
        let shadowImage = UIColor("#DBDBE6").creatImageWithSize(size: CGSize(width: UIScreen.main.bounds.width, height: 1.0 / UIScreen.main.scale))
        UINavigationBar.appearance().shadowImage = shadowImage
    }
}

extension AppDelegate {
    
    func handleInboxURL(_ url: URL) {
        let fileName = url.lastPathComponent
        let isToxFile = url.isToxURL()
        
        removeBlurView()
        
        guard isToxFile else {
            AlertViewManager.showMessageSheet(with: NSLocalizedString("This is not a tox profile", comment: ""), cancelTitle: NSLocalizedString("OK", comment: ""))
            
            return
        }
        
        if let homeViewController = window?.rootViewController as? HomeViewController {
            let chat = homeViewController.viewControllers?.first as! UINavigationController
            chat.popToRootViewController(animated: false)
        } else {
            let welcome = window?.rootViewController as! UINavigationController
            welcome.popToRootViewController(animated: false)
        }
        
        let importAction: AlertViewManager.Action = { [unowned self] in
            UserService.shared.logout()
            
            let nav: UINavigationController = self.window?.rootViewController as! UINavigationController
            let vc = RegisterViewController()
            vc.titleString = NSLocalizedString("Import Account", comment: "")
            vc.copyURL = url
            nav.pushViewController(vc, animated: false)
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

public func print<T>(file: String = #file, function: String = #function, line: Int = #line, _ message: T, color: UIColor = .white) {
    #if DEBUG
//    swiftLog(file, function, line, message, color, false)
    #endif
}
