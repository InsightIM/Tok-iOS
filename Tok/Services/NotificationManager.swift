//
//  NotificationManager.swift
//  Tok
//
//  Created by Bryce on 2018/6/28.
//  Copyright © 2018 Insight. All rights reserved.
//

import UserNotifications
import RxSwift
import RxCocoa

class NotificationManager: NSObject {
    private let messageService: MessageService
    private let manager: OCTManager
    
    private var messagesToken: RLMNotificationToken?
    private var unreadAllMessages: Results<OCTMessageAbstract>!
    private var unmuteGroupChats: Results<OCTChat>!
    fileprivate var unmuteGroupChatsToken: RLMNotificationToken?
    fileprivate var unreadAllMessagesToken: RLMNotificationToken?
    
    fileprivate var chats: Results<OCTChat>
    fileprivate var chatsToken: RLMNotificationToken?
    fileprivate var requests: Results<OCTFriendRequest>
    fileprivate var requestsToken: RLMNotificationToken?
    
    fileprivate let audioPlayer = AlertAudioPlayer()
    
    let chatsCountChanged = BehaviorRelay<Int>(value: 0)
    let requestsCountChanged = BehaviorRelay<Int>(value: 0)
    
    init(messageService: MessageService) {
        self.messageService = messageService
        self.manager = messageService.tokManager.toxManager
        chats = messageService.database.normalChats()
        unmuteGroupChats = messageService.database.normalChats(predicate: NSPredicate(format: "isMute == NO AND isGroup == YES"))

        let predicate = NSPredicate(format: "status == 0 AND isOutgoing == NO")
        requests = manager.objects.friendRequests(predicate: predicate)
        
        super.init()
        
        updateUnreadMessagesOberver()
        addNotificationBlocks()
    }
    
    deinit {
        messagesToken?.invalidate()
        chatsToken?.invalidate()
        requestsToken?.invalidate()
        unreadAllMessagesToken?.invalidate()
        unmuteGroupChatsToken?.invalidate()
    }
    
    func register() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .carPlay], completionHandler: { (granted, error) in
        })
    }
    
    func send(identifier: String, title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.badge = 1
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { error in
        })
    }
    
    func updateUnreadMessagesOberver() {
        unreadAllMessagesToken?.invalidate()
        unreadAllMessages = findAllUnreadMessage()
        unreadAllMessagesToken = unreadAllMessages.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                self.updateBadges()
                break
            case .update:
                self.updateBadges()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func findAllUnreadMessage() -> Results<OCTMessageAbstract> {
        let unmuteChats: [OCTChat] = messageService.database.normalChats(predicate: NSPredicate(format: "isMute == NO AND isGroup == NO")).toList()
        let subpredicate = NSPredicate(format: "chatUniqueIdentifier IN %@", unmuteChats.map { $0.uniqueIdentifier })
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            subpredicate,
            NSPredicate(format: "senderUniqueIdentifier != nil AND readed == NO")
            ])
        return messageService.database.findMessages(predicate: predicate)
    }
    
    func updateBadges() {
        DispatchQueue.global(qos: .default).async {
            let unmuteGroupChats: [OCTChat] = self.messageService.database.normalChats(predicate: NSPredicate(format: "isMute == NO AND isGroup == YES")).toList()
            let unreadAllMessages = self.findAllUnreadMessage()
            let unreadCount = unmuteGroupChats.map { $0.leftCount }.reduce(0, +) + unreadAllMessages.count
            
            let predicate = NSPredicate(format: "status == 0 AND isOutgoing == NO")
            let requests = self.messageService.database.findFriendRequest(predicate: predicate)
            let requestsCount = requests.count
            
            DispatchQueue.main.async {
                self.chatsCountChanged.accept(unreadCount)
                self.requestsCountChanged.accept(requestsCount)
                UIApplication.shared.applicationIconBadgeNumber = unreadCount + requestsCount
            }
        }
    }
    
    private func shouldNotifyMessage(_ message: OCTMessageAbstract) -> Bool {
        if message.isOutgoing() {
            return false
        }
        
        if UIApplication.shared.applicationState == .active {
            return false
        }
        
        if isMute(message) {
            return false
        }
        
        if message.messageText != nil || message.messageFile != nil {
            return true
        }
        
        return false
    }
    
    private func playSoundForMessageIfNeeded(_ message: OCTMessageAbstract) {
        if message.isOutgoing() {
            return
        }
        
        guard message.tokMessageType == .tempGroupMessage else {
            return
        }
        
        if isMute(message) {
            return
        }
        
        if message.messageText != nil || message.messageFile != nil {
            audioPlayer.playSound(.newMessage)
        }
    }
    
    private func isMute(_ message: OCTMessageAbstract) -> Bool {
        let chats = self.manager.objects.chats(predicate: NSPredicate(format: "uniqueIdentifier == %@ AND isMute == YES", message.chatUniqueIdentifier))
        return chats.count > 0
    }
    
    func showCallNotificationWithCaller(_ caller: OCTCall, userInfo: String) {
        let friend = caller.chat.friends?.firstObject() as? OCTFriend
        let title = friend?.nickname ?? "Tok User"
        let body = NSLocalizedString("is calling", comment: "")
        send(identifier: userInfo, title: title, subtitle: "", body: body)
    }
}

fileprivate extension NotificationManager {
    func addNotificationBlocks() {
        unmuteGroupChatsToken = unmuteGroupChats.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update:
                self.updateBadges()
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        let messages = manager.objects.messages().sortedResultsUsingProperty("dateInterval", ascending: false)
        messagesToken = messages.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let messages, _, let insertions, _):
                guard let messages = messages else {
                    break
                }
                if insertions.contains(0), let message = messages.firstObject {
                    self.playSoundForMessageIfNeeded(message)
                    
                    if self.shouldNotifyMessage(message) {
                        let title = "Tok"
                        let body = NSLocalizedString("New message", comment: "")
                        self.send(identifier: message.chatUniqueIdentifier, title: title, subtitle: "", body: body)
                    }
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        chatsToken = chats.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(_, let deletions, let insertions, _):
                if deletions.count > 0 || insertions.count > 0 {
                    self.updateUnreadMessagesOberver()
                    self.updateBadges()
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        requestsToken = requests.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(let requests, _, let insertions, _):
                guard let requests = requests else {
                    break
                }
                for index in insertions {
                    let request = requests[index]
                    
                    let title = NSLocalizedString("New Friend Request", comment: "")
                    
                    self.send(identifier: request.publicKey, title: title, subtitle: "", body: "")
                    self.audioPlayer.playSound(.newMessage)
                }
                self.updateBadges()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
