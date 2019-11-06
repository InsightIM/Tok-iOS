//
//  ForwardMessageViewController.swift
//  Tok
//
//  Created by Bryce on 2019/1/21.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

final class ForwardFriendViewController: ChooseFriendViewController {

    let viewModel: ForwardMessageViewModel
    
    init(viewModel: ForwardMessageViewModel) {
        self.viewModel = viewModel
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Select a Friend", comment: "")
        
        selectedCountChanges
            .map { $0 > 0 ? NSLocalizedString("Send", comment: "") + "(\($0))" : NSLocalizedString("Send", comment: "") }
            .bind(to: rightBarButtonItem.rx.title)
            .disposed(by: disposeBag)
        
        selectedCountChanges
            .map { $0 > 0 }
            .bind(to: rightBarButtonItem.rx.isEnabled)
            .disposed(by: disposeBag)
    }
    
    override func rightBarButtonItemClick(sender: Any?) {
        self.friends.filter { $0.isSelected.value }
            .forEach { viewModel in
                guard let chat = UserService.shared.toxMananger!.chats.getOrCreateChat(with: viewModel.friend) else {
                    return
                }
                
                sendMessage(to: chat)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    private func sendMessage(to chat: OCTChat) {
        viewModel.sendMessage(to: chat)
    }
}
