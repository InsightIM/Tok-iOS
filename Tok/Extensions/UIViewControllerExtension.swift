import UIKit
import SwiftMessages

extension UIViewController {

    var fullScreenSafeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *), let window = UIApplication.shared.keyWindow {
            let originalSafeAreaInsets = window.safeAreaInsets
            if originalSafeAreaInsets.top < 20.1 {
                return .zero
            } else {
                return originalSafeAreaInsets
            }
        } else {
            return .zero
        }
    }
    
    public func isPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    func alert(_ message: String, actionTitle: String = NSLocalizedString("OK", comment: ""), cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: message, message: nil, preferredStyle: UIAlertController.Style.alert)
        alc.addAction(UIAlertAction(title: actionTitle, style: UIAlertAction.Style.default, handler: cancelHandler))

        if let window = UIApplication.shared.windows.last, window.windowLevel.rawValue == CGFloat(10000001.0) {
            window.rootViewController?.present(alc, animated: true, completion: nil)
        } else {
            present(alc, animated: true, completion: nil)
        }
    }

    func alert(_ title: String?, message: String?, handler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alc.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertAction.Style.cancel, handler: handler))
        self.present(alc, animated: true, completion: nil)
    }

    func alert(_ title: String, message: String? = nil, cancelTitle: String = NSLocalizedString("Cancel", comment: ""), actionTitle: String, handler: @escaping ((UIAlertAction) -> Void)) {
        let alc = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alc.addAction(UIAlertAction(title: cancelTitle, style: UIAlertAction.Style.default, handler: nil))
        alc.addAction(UIAlertAction(title: actionTitle, style: UIAlertAction.Style.destructive, handler: handler))
        self.present(alc, animated: true, completion: nil)
    }

    func alertSettings(_ message: String) {
        
    }

//    func alertInput(title: String, placeholder: String, actionTitle: String = Localized.DIALOG_BUTTON_CHANGE, handler: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
//        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
//        controller.addTextField { (textField) in
//            textField.placeholder = placeholder
//        }
//        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
//        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: handler))
//        controller.actions[1].isEnabled = false
//        return controller
//    }

    func showOnWindow() {
        let win = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        win.rootViewController = vc
        win.windowLevel = UIWindow.Level.alert + 1
        win.makeKeyAndVisible()
        vc.present(self, animated: true, completion: nil)
    }
}

extension UIViewController {
    class func currentViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return currentViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return currentViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return currentViewController(base: presented)
        }
        return base
    }
    
    static func screenSnapshot() -> UIImage? {
        
        guard let window = UIApplication.shared.keyWindow else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, 0.0)
        
        window.layer.render(in: UIGraphicsGetCurrentContext()!)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}

extension UIViewController {
    func presentPrivacy(height: CGFloat? = nil) {
        let vc = PrivacyViewController()
        vc.view.heightAnchor.constraint(equalToConstant: height ?? UIScreen.main.bounds.height).isActive = true
        let segue = SwiftMessagesSegue(identifier: nil, source: self, destination: vc)
        segue.configure(layout: .bottomMessage)
        segue.perform()
    }
    
    func presentInvite(messageService: MessageService, parentViewController: UIViewController? = nil) {
        let vc = InviteFriendViewController(messageService: messageService)
        let navigationViewController = UINavigationController(rootViewController: vc)
        (parentViewController ?? self).present(navigationViewController, animated: true, completion: nil)
    }
}

extension UIViewController {
    func share(text: String, messageService: MessageService) {
        guard text.isNotEmpty else { return }

        AlertViewManager.showMessageSheet(with: text, actions: [
            (NSLocalizedString("Share to Friends", comment: ""), .default, { [unowned self] in
                let items: [Any] = [text]
                let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                self.present(vc, animated: true, completion: nil)
            }), (NSLocalizedString("Share to Chats", comment: ""), .default, { [unowned self] in
                let viewModel = ForwardMessageViewModel(text: text, messageService: messageService)
                let vc = ForwardChatViewController(viewModel: viewModel)
                let nav = UINavigationController(rootViewController: vc)
                self.present(nav, animated: true, completion: nil)
            }), (NSLocalizedString("Copy", comment: ""), .default, {
                UIPasteboard.general.string = text
            })
        ])
    }
}
