//
//  CreateGroupViewController.swift
//  FChat
//
//  Created by zhanghanbing on 2018/12/30.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

final class CreateGroupViewController: ChooseFriendViewController {
    
    var defaultSelectedViewModel: FriendSelectionViewModel?
    var publicGroup: Bool = false
    init(messageService: MessageService, friend: OCTFriend? = nil) {
        super.init(messageService: messageService)
        
        if let friend = friend {
            defaultSelectedViewModel = friends.first(where: { $0.uniqueIdentifier == friend.uniqueIdentifier })
            defaultSelectedViewModel?.isSelected.accept(true)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let groupType = publicGroup ? NSLocalizedString("Public", comment: "") : NSLocalizedString("Private", comment: "")
        title = String(format: NSLocalizedString("Create %@ Group", comment: ""), groupType)
        
        selectedCountChanges
            .map { $0 > 0 ? NSLocalizedString("Next", comment: "") + "(\($0))" : NSLocalizedString("Next", comment: "") }
            .bind(to: rightBarButtonItem.rx.title)
            .disposed(by: disposeBag)
        
        selectedCountChanges
            .map { $0 > 0 }
            .bind(to: rightBarButtonItem.rx.isEnabled)
            .disposed(by: disposeBag)
        
        if let defaultSelectedViewModel = defaultSelectedViewModel {
            searchView.addMember(viewModel: defaultSelectedViewModel)
        }
    }
    
    override func rightBarButtonItemClick(sender: Any?) {
        let vc = SetGroupNameViewController(messageService: messageService)
        vc.dataSource = self.friends
            .filter { $0.isSelected.value }
            .compactMap { viewModel in
                guard let model = viewModel.friend else {
                    return nil
                }
                return Friend(friend: model)
        }
        
        vc.publicGroup = publicGroup
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
