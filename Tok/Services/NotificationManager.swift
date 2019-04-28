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
    fileprivate let submanagerObjects: OCTSubmanagerObjects
    
    fileprivate var messagesToken: RLMNotificationToken?
    fileprivate var unreadAllMessagesToken: RLMNotificationToken?
    fileprivate var chats: Results<OCTChat>
    fileprivate var chatsToken: RLMNotificationToken?
    fileprivate var requests: Results<OCTFriendRequest>
    fileprivate var requestsToken: RLMNotificationToken?
    
    fileprivate let audioPlayer = AlertAudioPlayer()
    
    let chatsCountChanged = BehaviorRelay<Int>(value: 0)
    let requestsCountChanged = BehaviorRelay<Int>(value: 0)
    
    init(toxMananger: OCTManager) {
        submanagerObjects = toxMananger.objects
        chats = submanagerObjects.chats()
        requests = submanagerObjects.friendRequests()
        
        super.init()
        
        addNotificationBlocks()
    }
    
    deinit {
        messagesToken?.invalidate()
        chatsToken?.invalidate()
        requestsToken?.invalidate()
        unreadAllMessagesToken?.invalidate()
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
    
    func updateBadges() {
        let unreadAllMessages = submanagerObjects.messages(predicate: NSPredicate(format: "readed == NO"))
        let unreadCount = unreadAllMessages.count
        let requestsCount = requests.count
        
        chatsCountChanged.accept(unreadCount)
        requestsCountChanged.accept(requestsCount)
        
        UIApplication.shared.applicationIconBadgeNumber = unreadCount + requestsCount
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
        
        if isMute(message) {
            return
        }
        
        if message.messageText != nil || message.messageFile != nil {
            audioPlayer.playSound(.newMessage)
        }
    }
    
    private func isMute(_ message: OCTMessageAbstract) -> Bool {
        let chats = UserService.shared.toxMananger!.objects.chats(predicate: NSPredicate(format: "uniqueIdentifier == %@ AND isMute == YES", message.chatUniqueIdentifier))
        return chats.count > 0
    }
    
    func showCallNotificationWithCaller(_ caller: String, userInfo: String) {
        let title = caller
        let body = NSLocalizedString("is calling", comment: "")
        send(identifier: userInfo, title: title, subtitle: "", body: body)
    }
}

fileprivate extension NotificationManager {
    func addNotificationBlocks() {
        let unreadAllMessages = UserService.shared.toxMananger!.objects.messages(predicate: NSPredicate(format: "readed == NO"))
        unreadAllMessagesToken = unreadAllMessages.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            
            switch change {
            case .initial:
                break
            case .update(_, _, _, _):
                self.updateBadges()
            case .error(let error):
                fatalError("\(error)")
            }
        }
        
        let messages = submanagerObjects.messages().sortedResultsUsingProperty("dateInterval", ascending: false)
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
            case .update:
                self.updateBadges()
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
                    let body = request.message ?? ""
                    
                    self.send(identifier: request.publicKey, title: title, subtitle: "", body: body)
                    self.audioPlayer.playSound(.newMessage)
                }
                self.updateBadges()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
