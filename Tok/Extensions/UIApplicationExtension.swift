//
//  UIApplicationExtension.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

extension UIApplication {
    /// Avoid the error: [UIApplication sharedApplication] is unavailable in xxx extension
    ///
    /// - returns: UIApplication?
    public class func ts_sharedApplication() ->  UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: selector) else { return nil }
        return UIApplication.perform(selector).takeUnretainedValue() as? UIApplication
    }
    
    ///Get screen orientation
    public class var ts_screenOrientation: UIInterfaceOrientation? {
        guard let app = self.ts_sharedApplication() else {
            return nil
        }
        return app.statusBarOrientation
    }
    
    ///Get status bar's height
    @available(iOS 8.0, *)
    public class var ts_screenStatusBarHeight: CGFloat {
        guard let app = UIApplication.ts_sharedApplication() else {
            return 0
        }
        return app.statusBarFrame.height
    }
    
    /**
     Run a block in background after app resigns activity
     
     - parameter closure:           The closure
     - parameter expirationHandler: The expiration handler
     */
    public func ts_runIntoBackground(_ closure: @escaping () -> Void, expirationHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let taskID: UIBackgroundTaskIdentifier
            if let expirationHandler = expirationHandler {
                taskID = self.beginBackgroundTask(expirationHandler: expirationHandler)
            } else {
                taskID = self.beginBackgroundTask(expirationHandler: { })
            }
            closure()
            self.endBackgroundTask(taskID)
        }
    }
}

extension UIApplication {
    
    static var widthOfSafeArea: CGFloat {
        guard let rootView = UIApplication.shared.keyWindow else { return 0 }
        
        if #available(iOS 11.0, *) {
            
            let leftInset = rootView.safeAreaInsets.left
            
            let rightInset = rootView.safeAreaInsets.right
            
            return rootView.bounds.width - leftInset - rightInset
        } else {
            return rootView.bounds.width
        }
    }
    
    static var heightOfSafeArea: CGFloat {
        guard let rootView = UIApplication.shared.keyWindow else { return 0 }
        
        if #available(iOS 11.0, *) {
            
            let topInset = rootView.safeAreaInsets.top
            
            let bottomInset = rootView.safeAreaInsets.bottom
            
            return rootView.bounds.height - topInset - bottomInset
            
        } else {
            
            return rootView.bounds.height
            
        }
    }
    
    static var safeAreaInsets: UIEdgeInsets {
        guard let rootView = UIApplication.shared.keyWindow else { return UIEdgeInsets.zero }
        
        if #available(iOS 11.0, *) {
            
            return rootView.safeAreaInsets
            
        } else {
            
            return UIEdgeInsets.zero
            
        }
    }
    
}

extension UIApplication {
    
    static var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    static func rootNavigationController() -> UINavigationController? {
        let tabbar = UIApplication.shared.keyWindow?.rootViewController as? UITabBarController
        return tabbar?.selectedViewController as? UINavigationController
    }
    
    static func currentActivity() -> UIViewController? {
        return rootNavigationController()?.visibleViewController
    }
}

extension UIApplication {
    static func handleTokLink(text: String) {
        guard let link = URL(string: text.lowercased()), let host = link.host?.lowercased() else { return }
        guard let parameters = URLComponents(string: text.lowercased()) else { return }
        
        switch host {
        case "proxy":
            guard let server = parameters["server"],
                let portString = parameters["port"],
                server.validateIpOrHost(),
                portString.validatePort(),
                let port = UInt(portString) else {
                    return
            }
            
            let serverView = LinkInfoView(title: NSLocalizedString("Server", comment: ""), detail: server)
            let portView = LinkInfoView(title: NSLocalizedString("Port", comment: ""), detail: portString)
            let stackView = UIStackView(arrangedSubviews: [serverView, portView])
            stackView.axis = .vertical
            stackView.addBottomLine()
            
            AlertViewManager.showActionSheet(customView: stackView, actions: [
                (NSLocalizedString("Save", comment: ""), .default, {
                    ProxyModel.add(model: ProxyModel(server: server, port: port, username: nil, password: nil, selected: true))
                    UserDefaultsManager().proxyEnabled = true
                })
            ])
        case "bootstrap":
            guard let server = parameters["server"],
                let portString = parameters["port"],
                let network = parameters["protocol"]?.uppercased(),
                let networkProtocol = NodeModel.NetworkProtocol(rawValue: network),
                let publicKey = parameters["publickey"]?.uppercased(),
                server.validateIpOrHost(),
                portString.validatePort(),
                let port = UInt(portString),
                publicKey.count == kOCTToxPublicKeyLength else {
                    return
            }
            let serverView = LinkInfoView(title: NSLocalizedString("Node Address", comment: ""), detail: server)
            let portView = LinkInfoView(title: NSLocalizedString("Node Port", comment: ""), detail: portString)
            let networkView = LinkInfoView(title: NSLocalizedString("Network Protocol", comment: ""), detail: network)
            let publicKeyView = LinkInfoView(title: NSLocalizedString("Node Public Key", comment: ""), detail: publicKey)
            let stackView = UIStackView(arrangedSubviews: [serverView, portView, networkView, publicKeyView])
            stackView.axis = .vertical
            stackView.addBottomLine()
            
            AlertViewManager.showActionSheet(customView: stackView, actions: [
                (NSLocalizedString("Save", comment: ""), .default, {
                    NodeModel.add(model: NodeModel(server: server, port: port, publicKey: publicKey, networkProtocol: networkProtocol))
                }),
                (NSLocalizedString("Connect", comment: ""), .default, {
                    NodeModel.add(model: NodeModel(server: server, port: port, publicKey: publicKey, networkProtocol: networkProtocol))
                    UserDefaultsManager().customBootstrapEnabled = true
                    UserService.shared.bootstrap()
                })
            ])
        default: return
        }
    }
}

extension URLComponents {
    subscript(name: String) -> String? {
        return queryItems?.first(where: { $0.name == name })?.value
    }
}

class LinkInfoView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor("#666666")
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .tokTitle4
        label.lineBreakMode = .byTruncatingMiddle
        label.textAlignment = .right
        return label
    }()
    
    init(title: String, detail: String) {
        super.init(frame: .zero)
        backgroundColor = .white
        
        addSubview(titleLabel)
        addSubview(detailLabel)
        
        titleLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(16)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        detailLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.trailing.equalTo(-16)
            make.top.equalToSuperview()
            make.width.equalTo(titleLabel)
            make.height.equalTo(titleLabel)
        }
        
        titleLabel.text = title
        detailLabel.text = detail
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
