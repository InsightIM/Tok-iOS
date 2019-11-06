//
//  FriendSelectionViewModel.swift
//  Tok
//
//  Created by Bryce on 2018/12/15.
//  Copyright © 2018年 Insight. All rights reserved.
//

import RxSwift
import RxCocoa

class FriendSelectionViewModel {
    var indexPath: IndexPath?
    
    let uniqueIdentifier: String
    private(set) var name: String = ""
    private(set) var isDisabled = false
    let isSelected: BehaviorRelay<Bool>
    
    private(set) var friend: OCTFriend?
    private(set) var peer: Peer?
    let image: UIImage?
    
    init(friend: OCTFriend, messageService: MessageService, isDisabled: Bool = false) {
        self.uniqueIdentifier = friend.uniqueIdentifier
        self.friend = friend
        self.isDisabled = isDisabled
        self.isSelected = BehaviorRelay(value: false)
        name = friend.nickname
        image = AvatarManager.shared.image(bySenderId: friend.publicKey, messageService: messageService)
    }
    
    init(peer: Peer) {
        self.uniqueIdentifier = ""
        self.peer = peer
        self.isSelected = BehaviorRelay(value: false)
        name = peer.nickname
        image = peer.avatar
    }
}
