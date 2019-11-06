//
//  ChatsViewModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/27.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import DeepDiff
import RxSwift
import RxCocoa

class ChatsViewModel {
    private let chat: OCTChat
    
    let id: String
    
    private let friend: OCTFriend?
    
    let userStatusViewHidden: Bool
    
    let name: String
    
    let userStatus: UserStatus
    
    let lastMessageText: BehaviorRelay<(Bool, String?, String)>
    
    private(set) var lastActivityDate: String?
    
    let avatar = BehaviorRelay<UIImage?>(value: nil)
    
    let isMuted: Bool
    
    let verified: Bool
    
    let unreadCount = BehaviorRelay<String?>(value: nil)
    
    private let database: Database
    
    private let fileService: FileService

    init(chat: OCTChat, messageService: MessageService, timeFormatter: DateFormatter, dateFormatter: DateFormatter, cache: NSCache<AnyObject, UIImage>) {
        self.chat = chat
        self.database = messageService.database
        
        id = chat.uniqueIdentifier
        friend = chat.friends?.firstObject() as? OCTFriend
        userStatusViewHidden = chat.isGroup
        isMuted = chat.isMute
        verified = chat.isVerified
        fileService = messageService.fileService
        
        name = chat.isGroup
            ? (chat.title ?? "Group \(chat.groupNumber)")
            : (friend?.nickname ?? "")
        
        userStatus = chat.isGroup
            ? .offline
            : UserStatus(connectionStatus: friend?.connectionStatus, userStatus: friend?.status)
        
        if let date = chat.lastActivityDate() {
            let isToday = (Calendar.current as NSCalendar).compare(Date(), to: date, toUnitGranularity: .day) == .orderedSame
            let time = isToday ? timeFormatter.string(from: date) : dateFormatter.string(from: date)
            lastActivityDate = time
        }
        
        lastMessageText = BehaviorRelay(value: self.database.findLastMessage(withChatId: self.id))
        avatar.accept(getAvatar(cache: cache))
        
        let count = chat.isGroup ? chat.leftCount : messageService.database.findUnreadMessage(withChatId: id).count
        self.updateUnreadCount(messageCount: count)
    }
    
    private func getAvatar(cache: NSCache<AnyObject, UIImage>) -> UIImage? {
        if let image = cache.object(forKey: id as AnyObject) {
            return image
        }
        let avatar = AvatarManager.shared.chatAvatar(chatId: self.id, database: self.database)
        if let image = avatar {
            cache.setObject(image, forKey: self.id as AnyObject)
        }
        return avatar
    }
    
    private func updateUnreadCount(messageCount: Int) {
        let count = messageCount > 0 ? "\(messageCount)" : nil
        self.unreadCount.accept(count)
    }
}

extension ChatsViewModel: DiffAware {
    typealias DiffId = String
    
    var diffId: String {
        return id
    }
    
    static func compareContent(_ a: ChatsViewModel, _ b: ChatsViewModel) -> Bool {
        return a.name == b.name
            && a.userStatus == b.userStatus
            && a.userStatusViewHidden == b.userStatusViewHidden
            && a.lastMessageText.value == b.lastMessageText.value
            && a.isMuted == b.isMuted
            && a.lastActivityDate == b.lastActivityDate
            && a.unreadCount.value == b.unreadCount.value
    }
}
