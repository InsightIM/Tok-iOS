//
//  TextMessageHandler.swift
//  Tok
//
//  Created by Bryce on 2019/7/15.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions
import SafariServices

class TextMessageHandler: BaseMessageHandler {
    
    override func userDidTapOnDetectedString(text: String, detectedDataType: DetectedDataType, viewModel: MessageViewModelProtocol) {
        parentViewController?.view.endEditing(true)
        switch detectedDataType {
        case .URL:
            guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()) else {
                return
            }
            let title = NSLocalizedString("This is an External Website Links. Are you sure you want to proceed?", comment: "")
            AlertViewManager.showMessageSheet(with: title, actions: [
                (NSLocalizedString("Yes", comment: ""), UIAlertAction.Style.default, { [unowned self] in
                    let vc = SFSafariViewController(url: url)
                    self.parentViewController?.present(vc, animated: true)
                })
            ])
        case .tokId:
            let alertController = UIAlertController(title: NSLocalizedString("Confirm to send friend request", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField(configurationHandler: { textField in
                textField.text = String(format: NSLocalizedString("Hi, i'm %@", comment: ""), UserService.shared.nickName ?? "Tok User")
                textField.clearButtonMode = .whileEditing
            })
            
            let confirmAction = UIAlertAction(title: "OK", style: .default) { [unowned self, weak alertController] _ in
                guard let alertController = alertController, let textField = alertController.textFields?.first else { return }
                self.dataSource.messageService.friendService.sendFriendRequest(address: text, message: textField.text ?? "")
            }
            
            alertController.addAction(confirmAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            parentViewController?.present(alertController, animated: true, completion: nil)
        case .groupId:
            let title = String(format: NSLocalizedString("Do you want to view group %@", comment: ""), text)
            AlertViewManager.showMessageSheet(with: title, actions: [(NSLocalizedString("View", comment: ""), .default, { [unowned self] in
                let vc = GroupViewerViewController(groupShareId: text, messageService: self.dataSource.messageService)
                self.parentViewController?.navigationController?.pushViewController(vc, animated: true)
            })])
        case .tokLink:
            UIApplication.handleTokLink(text: text)   
        }
    }
}
