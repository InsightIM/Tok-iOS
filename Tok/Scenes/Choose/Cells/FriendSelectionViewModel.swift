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
    
    private(set) var name: String = ""
    private(set) var isDisabled = false
    let isSelected = BehaviorRelay(value: false)
    
    let friend: OCTFriend
    
    init(friend: OCTFriend, isDisabled: Bool = false) {
        self.friend = friend
        self.isDisabled = isDisabled
        name = friend.nickname
    }
}
