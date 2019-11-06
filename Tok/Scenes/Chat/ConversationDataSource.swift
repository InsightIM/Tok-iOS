//
//  ConversationDataSource.swift
//  Tok
//
//  Created by Bryce on 2019/5/17.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation
import Chatto
import ChattoAdditions
import RxSwift
import RxCocoa

class ConversationDataSource: ChatDataSourceProtocol {
    private let disposeBag = DisposeBag()
    private let preferredMaxWindowSize = 5000
    
    fileprivate let messageAbstracts: Results<OCTMessageAbstract>!
    fileprivate var messagesToken: RLMNotificationToken?
    
    private var slidingWindow: SlidingDataSource<ChatItemProtocol>!
    
    var scrollAtBottom = false
    let pageLoading = BehaviorRelay(value: false)
    
    let toxManager: OCTManager
    let messageSender: MessagesSender
    let messageReceiver: MessageReceiver
    let messageService: MessageService
    let chat: OCTChat
    let chatId: String
    
    private let pageSize: Int
    init(messageService: MessageService, chat: OCTChat, pageSize: Int = 50) {
        self.messageService = messageService
        self.toxManager = messageService.tokManager.toxManager
        self.messageSender = messageService.messageSender
        self.messageReceiver = messageService.messageReceiver
        self.chat = chat
        self.chatId = chat.uniqueIdentifier
        self.pageSize = pageSize
        
        enteredText = chat.enteredText
        messageAbstracts = messageSender.database.messages(of: chat)
        
        slidingWindow = SlidingDataSource(count: messageAbstracts.count, pageSize: pageSize) { [unowned self] index in
            return self.messageAbstracts[index].toMessageModel(isGroup: self.chat.isGroup, fileService: self.messageService.fileService)
        }
        
        messageReceiver.didPullMessage
            .filter { [weak self] result in
                guard let self = self else { return false }
                return result.chatId == self.chatId
            }
            .observeOn(MainScheduler.instance)
            .debug("didPullMessage")
            .subscribe(onNext: { [weak self] result in
                guard let self = self else { return }
                if result.tail {
                    let updateType = self.scrollAtBottom ? UpdateType.normal : UpdateType.pagination
                    self.delegate?.chatDataSourceDidUpdate(self, updateType: updateType, completion: { [weak self] in
                        self?.pageLoading.accept(false)
                    })
                } else if result.up {
                    if self.hasMorePrevious {
                        self.loadPrevious()
                    }
                    if !result.error {
                        self.pageLoading.accept(false)
                    }
                }
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(.NewMessagesDidReceive)
            .filter { [weak self] notification in
                guard let self = self else { return false }
                return (notification.object as? String) == self.chatId
            }
            .subscribe(onNext: { [weak self] _ in
                self?.pullTailMessages()
            })
            .disposed(by: disposeBag)
        
        pullTailMessages()
        addMessagesNotification()
    }
    
    deinit {
        print("\(self) deinit")
        messagesToken?.invalidate()
    }
    
    // MARK: - Public
    
    let enteredText: String?
    
    let longPressAvatar = PublishSubject<String>()
    
    var chatItems: [ChatItemProtocol] {
        return self.slidingWindow.itemsInWindow
    }
    
    weak var delegate: ChatDataSourceDelegateProtocol?
    
    var hasMoreNext: Bool {
        return self.slidingWindow.hasMore()
    }
    
    var hasMorePrevious: Bool {
        return self.slidingWindow.hasPrevious()
    }
    
    func loadNext() {
        self.slidingWindow.loadNext()
        self.slidingWindow.adjustWindow(focusPosition: 1, maxWindowSize: self.preferredMaxWindowSize)
        self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination, completion: { [weak self] in
            self?.pageLoading.accept(false)
        })
    }
    
    func loadPrevious() {
        self.slidingWindow.loadPrevious()
        self.slidingWindow.adjustWindow(focusPosition: 0, maxWindowSize: self.preferredMaxWindowSize)
        #if DEBUG
        print("🌶🌶🌶 [loadPrevious] updateType pagination🌶🌶🌶")
        #endif
        self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination, completion: { [weak self] in
            self?.pageLoading.accept(false)
        })
    }
    
    private var skipOnce = false
    func pullMessageIfNeeded(up: Bool) {
        guard skipOnce else {
            skipOnce = true
            return
        }
        guard pageLoading.value == false else { return }
        pageLoading.accept(true)
        let startTimeInterval = ((chatItems.filter { $0.type != SystemMessageModel.chatItemType }.first as? MessageModelProtocol)?.date.timeIntervalSince1970 ?? 0)
        let endTimeInterval = ((chatItems.last as? MessageModelProtocol)?.date.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
//        let dateInterval = up
//            ? ((chatItems.filter { $0.type != SystemMessageModel.chatItemType }.first as? MessageModelProtocol)?.date.timeIntervalSince1970 ?? 0)
//            : ((chatItems.last as? MessageModelProtocol)?.date.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        messageService.pullGroupMessagesIfNeeded(chatId: chatId, startTimeInterval: startTimeInterval, endTimeInterval: endTimeInterval, up: up, tail: false, pageSize: pageSize)
    }
    
    func pullTailMessages() {
        let startTimeInterval = ((chatItems.filter { $0.type != SystemMessageModel.chatItemType }.first as? MessageModelProtocol)?.date.timeIntervalSince1970 ?? 0)
        let endTimeInterval = ((chatItems.last as? MessageModelProtocol)?.date.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        messageService.pullGroupMessagesIfNeeded(chatId: chatId, startTimeInterval: startTimeInterval, endTimeInterval: endTimeInterval, up: true, tail: true, pageSize: pageSize)
    }
    
    func change(enterdText: String) {
        messageService.change(chatId: chatId, enteredText: enterdText)
    }
    
    func addTextMessage(_ text: String) {
        messageSender.add(text: text, to: chatId)
        change(enterdText: "")
    }
    
    func addAudioMessage(url: URL, duration: UInt) {
        guard let data = try? Data(contentsOf: url) else {
            return
        }
        let fileName = buildAudioFileName(duration)
        messageSender.sendFile(data: data, fileName: fileName, to: chat, needMove: true) { error in
            let view = UIApplication.shared.keyWindow
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: view)
        }
    }
    
    func addFileMessage(url: URL) {
        let fileName = url.lastPathComponent
        messageSender.sendFile(url: url, fileName: fileName, to: chat, needMove: true) { error in
            let view = UIApplication.shared.keyWindow
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: view)
        }
    }
    
    func addPhotoMessage(_ image: UIImage, isOriginal: Bool) {
        let theData = isOriginal ? image.jpegData(compressionQuality: 0.9) : image.compress()
        guard let data = theData else {
            return
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        messageSender.sendFile(data: data, fileName: fileName, to: chat, needMove: true) { error in
            let view = UIApplication.shared.keyWindow
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: view)
        }
    }
    
    func addVideoMessage(_ url: URL) {
        addFileMessage(url: url)
    }
    
    func deleteMessage(id: String) {
        messageService.database.deleteMessage(by: id)
    }
    
    func resend(message: ChatItemProtocol) {
        messageSender.resend(id: message.uid) { error in
            let view = UIApplication.shared.keyWindow
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: view)
        }
    }
    
    func resume(id: String) {
        messageService.fileService.resumeFileMessage(id: id)
    }
    
    func markAllMessageAsRead() {
        messageService.markAllMessagesAsRead(chatId: chat.uniqueIdentifier)
    }
    
    func markMessageAsRead(id: String) {
        messageService.markMessageAsRead(id: id)
    }
    
    func fetchGroupInfoIfNeeded() {
        guard chat.isGroup else { return }
        messageService.fetch(groupInfo: UInt64(chat.groupNumber)).subscribe().disposed(by: disposeBag)
    }
    
    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> Void) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition, maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }
    
    func setAudioAsReaded(id: String) {
        messageService.setAudioAsReaded(id: id, withoutNotifying: nil)
    }
    
    func cancelFileMessage(id: String, isIncoming: Bool) {
        messageService.cancelFileMessage(id: id, isIncoming: isIncoming)
    }
    
    // MARK: - Private
    
    private func buildAudioFileName(_ duration: UInt) -> String {
        return "\(UUID().uuidString)_\(duration).\(audioExtension)"
    }
}

extension ConversationDataSource {
    private func addMessagesNotification() {
        self.messagesToken = messageAbstracts.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update(let results, let deletes, let insertions, _):
                guard let results = results else { return }
                
//                #if DEBUG
//                print("🐶🐶🐶🐶🐶 results.count \(results.count)")
//                deletes.forEach { print("--🐶🐶🐶🐶🐶delete index: \($0)") }
//                insertions.forEach { print("--🐶🐶🐶🐶🐶insert index: \($0)") }
//                modifications.forEach { print("--🐶🐶🐶🐶🐶modify index: \($0)") }
//                #endif
                
                let diffCount = insertions.count - deletes.count
                let startIndex = max((results.count - self.slidingWindow.items.count - diffCount), 0)
                guard results.count > startIndex else { return }
                let newItems = (startIndex..<results.count)
                    .map {
                        results[$0].toMessageModel(isGroup: self.chat.isGroup, fileService: self.messageService.fileService)
                }
                
                self.slidingWindow.resetItems(newItems: newItems, count: results.count)
                if self.chat.isGroup == false {
                    self.delegate?.chatDataSourceDidUpdate(self, updateType: .normal, completion: nil)
                } else {
                    let updateType = (self.scrollAtBottom && (insertions.count > 0 || deletes.count > 0)) ? UpdateType.normal : UpdateType.pagination
                    self.delegate?.chatDataSourceDidUpdate(self, updateType: updateType, completion: nil)
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
}
