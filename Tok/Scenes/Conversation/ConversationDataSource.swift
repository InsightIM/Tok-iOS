//
//  ConversationDataSource.swift
//  Tok
//
//  Created by Bryce on 2018/9/10.
//  Copyright © 2018年 Insight. All rights reserved.
//

import RxSwift
import RxCocoa
import SwiftDate
import DeepDiff

class ConversationDataSource {
    
    let disposeBag = DisposeBag()
    
    let chat: OCTChat
    
    private(set) var messageList = [MessageModel]()
    
    let isDisabled = BehaviorRelay(value: false)
    
//    let batchUpdates = PublishSubject<(IndexSet, [IndexPath], IndexSet, Bool)>()
    weak var collectionView: UICollectionView?
    
    let errors = PublishSubject<String>()
    
    let audioPlayer = AlertAudioPlayer()
    
    let titleUpdated = BehaviorRelay(value: ("", "", UserStatus.offline, false, false))
    
    let hasMore = BehaviorRelay(value: true)
    
    let findFriendBot = FindFriendBotModel()
    
    let offlineBot = OfflineBotModel()
    
    // MARK: - Private
    
    fileprivate let chats: OCTSubmanagerChats
    fileprivate let messageAbstracts: Results<OCTMessageAbstract>!
//    fileprivate var peers: Results<OCTPeer>?
    
    fileprivate var messagesToken: RLMNotificationToken?
    fileprivate var friendToken: RLMNotificationToken?
//    fileprivate var peersToken: RLMNotificationToken?
    fileprivate var chatToken: RLMNotificationToken?
    
    fileprivate lazy var groupBot = GroupBotModel()
    
    fileprivate lazy var sender: Sender = {
        let id = UserService.shared.toxMananger!.user.publicKey
        let name = UserService.shared.nickName ?? id
        return Sender(id: id, displayName: name)
    }()
    
    private let avatarCache = NSCache<NSString, UIImage>()
    private let nameCache = NSCache<NSString, NSString>()
    
    private var initialTotal = 0
    private let pageSize = 15
    
    private var hasResend = false
    
    let messageSender: MessageSender
    init(chat: OCTChat, messageSender: MessageSender) {
        self.chat = chat
        self.messageSender = messageSender
        self.chats = UserService.shared.toxMananger!.chats
        
        let predicate = NSPredicate(format: "chatUniqueIdentifier == %@", chat.uniqueIdentifier)
        messageAbstracts = UserService.shared.toxMananger!.objects.messages(predicate: predicate).sortedResultsUsingProperty("dateInterval", ascending: true)
        initialTotal = messageAbstracts.count
        hasMore.accept(messageAbstracts.count > 0)
        
        addMessagesNotification()
        addFriendNotification()
//        addPeersNotification()
        addGroupChatNotification()
        bindOnline()
        
        titleUpdated
            .distinctUntilChanged { $0.1 == $1.1 }
            .debug("titleUpdatedForQuery")
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.queryFriendIsSupportOfflineMessage()
            })
            .disposed(by: disposeBag)
        
        loadData()
    }
    
    deinit {
        messagesToken?.invalidate()
        friendToken?.invalidate()
//        peersToken?.invalidate()
        chatToken?.invalidate()
        NotificationCenter.default.removeObserver(self)
        
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
    
    func loadData() {
        guard hasMore.value else {
            return
        }
        
        let total = initialTotal
        let displayTotal = messageList.count
        
        let endIndex = total - displayTotal
        let startIndex = max(endIndex - pageSize, 0)
        
        for i in (startIndex..<endIndex).reversed() {
            let messageAbstract = messageAbstracts[i]
            
            let sender = messageAbstract.isOutgoing()
                ? self.sender
                : Sender(id: messageAbstract.senderUniqueIdentifier!, displayName: getName(messageAbstract: messageAbstract))
            let fileStorage = UserService.shared.toxMananger!.configuration().fileStorage
            let model = MessageModel(model: messageAbstract, sender: sender, fileStorage: fileStorage)
            messageList.insert(model, at: 0)
        }
        
        hasMore.accept(endIndex > pageSize)
    }
    
    func avatarFor(indexPath: IndexPath) -> UIImage? {
        let message = messageList[indexPath.section]
        if isFromCurrentSender(message: message) {
            return UserService.shared.avatarImage
        }
        
        if chat.isGroup {
            return getPeerAvatar(indexPath: indexPath)
        }
        
        if let friend = self.chat.friends?.firstObject() as? OCTFriend {
            if let avatar = friend.avatarData {
                return UIImage(data: avatar)
            }
            return AvatarManager.shared.image(with: friend)
        }
        return AvatarManager.shared.avatarFromString(identityNumber: Int(arc4random()), "?", diameter: 40)
    }
    
    func isFindFriendBot() -> Bool {
        guard let friend = chat.friends?.firstObject() as? OCTFriend else {
            return false
        }
        return friend.publicKey == findFriendBot.publicKey
    }
    
    // MARK: - Private Methods
    
    private func bindOnline() {
        guard chat.isInvalidated == false else {
            return
        }
        if chat.isGroup {
            bindGroupStatus()
        } else {
            bindFriendStatus()
        }
    }
    
    lazy var updateGroupInfoOnce: Void = {
        guard chat.groupStatus == 0 else {
            return
        }
        UserService.shared.toxMananger!.chats.getGroupInfo(withGroupNumber: chat.groupNumber)
    }()
    
    private func bindGroupStatus() {
        guard let bot = groupBot.getBot() else {
            return
        }
        
        let title = chat.title ?? "Group \(chat.groupNumber)"
        let groupType = chat.groupType == 1 ? " · \(NSLocalizedString("Public Group", comment: ""))" : ""
        let members =  "\(chat.groupMemebersCount) \(NSLocalizedString("Members", comment: ""))"
        
        let subTitle = bot.isConnected
            ? members + groupType
            : NSLocalizedString("Secure connecting...", comment: "")
        
        let status: UserStatus = bot.isConnected ? .online : .offline
        if bot.isConnected {
            _ = updateGroupInfoOnce
        }
        titleUpdated.accept((title, subTitle, status, chat.isMute, false))
    }
    
    private func bindFriendStatus() {
        guard let friend = chat.friends?.firstObject() as? OCTFriend else {
            return
        }
        
        let verified = friend.publicKey == UserDefaults.offlineBotPublicKey
        if friend.isConnected == false, friend.supportOfflineMessage, let bot = offlineBot.getBot() {
            let statusString = bot.isConnected
                ? NSLocalizedString("Away", comment: "")
                : NSLocalizedString("Peer-to-peer connecting...", comment: "")
            let botStatus: UserStatus = bot.isConnected ? .away : .offline
            titleUpdated.accept((friend.nickname, statusString, botStatus, false, verified))
        } else {
            let status: UserStatus = friend.isConnected ? .online : .offline
            titleUpdated.accept((friend.nickname, status.toString(), status, false, verified))
        }
    }
    
    private func queryFriendIsSupportOfflineMessage() {
        guard chat.isGroup == false else {
            return
        }
        guard OfflineBotModel().beAdded else {
            return
        }
        guard let friend = chat.friends?.firstObject() as? OCTFriend else {
            return
        }
        
        chats.queryFriendIsSupportOfflineMessage(friend)
    }
    
    private func addMessagesNotification() {
        self.messagesToken = messageAbstracts.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update(let results, let deletes, let insertions, _):
                guard let results = results else { return }
                
                var newItems = [MessageModel]()
                let startIndex = max((results.count - self.messageList.count - insertions.count + deletes.count), 0)
                for index in startIndex..<results.count {
                    let messageAbstract = results[index]
                    let model = self.convertModel(model: messageAbstract)
                    newItems.append(model)
                }
                
                let changes = diff(old: self.messageList, new: newItems)
                let needScrollToBottom = self.hasResend || self.collectionView?.isScrolledAtBottom() == true
                self.collectionView?.reloadSections(changes: changes, updateData: {
                    self.initialTotal = results.count
                    self.messageList = newItems
                }, completion: { finished in
                    if needScrollToBottom, finished {
                        self.collectionView?.scrollToBottom(true)
                    }
                })
                
                self.hasResend = false
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func addFriendNotification() {
        var predicate: NSPredicate
        if chat.isGroup {
            guard let bot = groupBot.getBot() else {
                return
            }
            predicate = NSPredicate(format: "uniqueIdentifier == %@", bot.uniqueIdentifier)
        } else {
            guard let friend = chat.friends?.firstObject() as? OCTFriend else {
                return
            }
            
            if let bot = offlineBot.getBot() {
                predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "uniqueIdentifier == %@", friend.uniqueIdentifier),
                    NSPredicate(format: "uniqueIdentifier == %@", bot.uniqueIdentifier),
                    ])
            } else {
                predicate = NSPredicate(format: "uniqueIdentifier == %@", friend.uniqueIdentifier)
            }
        }
        
        let results = UserService.shared.toxMananger!.objects.friends(predicate: predicate)
        
        friendToken = results.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update:
                self.bindOnline()
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
//    private func addPeersNotification() {
//        guard chat.isGroup else {
//            return
//        }
//
//        peers = UserService.shared.toxMananger!.objects.peers(predicate: NSPredicate(format: "groupNumber == %lld", chat.groupNumber))
//
//        peersToken = peers?.addNotificationBlock { [weak self] change in
//            guard let self = self else { return }
//            switch change {
//            case .initial:
//                break
//            case .update(let results, _, _, _):
//                guard let _ = results else { return }
//                self.bindOnline()
//            case .error(let error):
//                fatalError("\(error)")
//            }
//        }
//    }
    
    private func addGroupChatNotification() {
        guard chat.isGroup else {
            return
        }
        isDisabled.accept(chat.groupStatus != 0)
        let groupChat = UserService.shared.toxMananger!.objects.chats(predicate: NSPredicate(format: "uniqueIdentifier == %@", chat.uniqueIdentifier))
        
        chatToken = groupChat.addNotificationBlock { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .initial:
                break
            case .update(let results, _, _, _):
                guard let results = results else { return }
                self.bindOnline()
                if let groupChat = results.firstObject {
                    self.isDisabled.accept(groupChat.groupStatus != 0)
                }
            case .error(let error):
                fatalError("\(error)")
            }
        }
    }
    
    private func getPeerAvatar(indexPath: IndexPath) -> UIImage? {
        let message = messageList[indexPath.section]
        let senderPublicKey = message.message.senderPublicKey as NSString
        if message.message.senderPublicKey.isNotEmpty,
            let image = avatarCache.object(forKey: senderPublicKey) {
            return image
        }
        
        let result = UserService.shared.toxMananger!.objects.peers(predicate: NSPredicate(format: "groupNumber == %lld AND publicKey == %@", chat.groupNumber, message.message.senderPublicKey))
        let peer = result.firstObject
        if let data = peer?.avatarData, let image = UIImage(data: data) {
            avatarCache.setObject(image, forKey: senderPublicKey)
            return image
        }
        if let peer = peer, let temp = AvatarManager.shared.image(with: peer) {
            avatarCache.setObject(temp, forKey: senderPublicKey)
            return temp
        }
        
        let random = AvatarManager.shared.avatarFromString(identityNumber: Int(arc4random()), peer?.nickname ?? "?", diameter: 40)
        avatarCache.setObject(random, forKey: senderPublicKey)
        return random
    }
    
    private func getName(messageAbstract: OCTMessageAbstract) -> String {
        guard chat.isGroup else {
            return (chat.friends?.firstObject() as! OCTFriend).nickname
        }
        
        let publicKey = messageAbstract.senderPublicKey
        if publicKey.isNotEmpty, let name = nameCache.object(forKey: publicKey as NSString) {
            return name as String
        }
        
        let friend = UserService.shared.toxMananger!.objects.friends(predicate: NSPredicate(format: "publicKey == %@", publicKey)).firstObject
        if let friend = friend {
            nameCache.setObject((friend.nickname as NSString), forKey: publicKey as NSString)
            return friend.nickname
        }
        
        let result = UserService.shared.toxMananger!.objects.peers(predicate: NSPredicate(format: "publicKey == %@", publicKey))
        guard let peer = result.firstObject else {
            return ""
        }
        if let name = peer.nickname {
            nameCache.setObject((name as NSString), forKey: publicKey as NSString)
            return name as String
        } else if let pk = peer.publicKey, pk.isNotEmpty {
            let temp = (pk as NSString).substring(to: 6)
            nameCache.setObject((temp as NSString), forKey: publicKey as NSString)
            return temp
        }
        
        return ""
    }
}

extension ConversationDataSource {
    func addTextMessage(_ text: String) {
        guard checkGroupStatus() else {
            return
        }
        var string = text
        if isFindFriendBot(), text.lowercased() == FindFriendBotModel.Command.start.rawValue {
            string = text + " " + UserService.shared.toxMananger!.user.userAddress
        }
        messageSender.add(text: string, to: chat)
        UserService.shared.toxMananger!.objects.change(chat, enteredText: "")
    }
    
    func addPhotoMessage(_ image: UIImage, isOriginal: Bool = false) {
        let theData = isOriginal ? image.jpegData(compressionQuality: 0.9) : image.compress()
        guard let data = theData else {
            return
        }
        
        let fileName = "\(Date().timeIntervalSince1970 * 1000).jpg"
        sendFile(data: data, fileName: fileName)
    }
    
    func addFileMessage(_ fileUrl: URL) {
        sendFile(url: fileUrl)
    }
    
    func addAudioMessage(_ fileUrl: URL, _ duration: Int) {
        guard let data = try? Data(contentsOf: fileUrl) else {
            return
        }
        
        sendFile(data: data, fileName: buildAudioFileName(duration))
    }
    
    private func sendFile(data: Data, fileName: String) {
        guard checkGroupStatus() else {
            return
        }
        let submanagerFiles = UserService.shared.toxMananger!.files
        submanagerFiles.send(data, withFileName: fileName, to: chat) { [weak self] error in
            guard let self = self else { return }
            
            let error = error as NSError
            if error.domain == kOCTManagerErrorDomain, error.code == OCTSendFileError.offlineFileTooBig.rawValue {
                self.errors.onNext(NSLocalizedString("Only offline files smaller than 10M are supported", comment: ""))
            } else if let errorMessage = error.localizedFailureReason {
                self.errors.onNext(errorMessage)
            }
        }
    }
    
    private func sendFile(url: URL) {
        guard checkGroupStatus() else {
            return
        }
        let submanagerFiles = UserService.shared.toxMananger!.files
        submanagerFiles.sendFile(atPath: url.standardizedFileURL.path, fileName: url.lastPathComponent, moveToUploads: true, to: chat) { [weak self] error in
            guard let self = self else { return }
            
            let error = error as NSError
            if error.domain == kOCTManagerErrorDomain, error.code == OCTSendFileError.offlineFileTooBig.rawValue {
                self.errors.onNext(NSLocalizedString("Only offline files smaller than 10M are supported", comment: ""))
            } else if let errorMessage = error.localizedFailureReason {
                self.errors.onNext(errorMessage)
            }
        }
    }
    
    private func resendFile(message: OCTMessageAbstract) {
        guard checkGroupStatus() else {
            return
        }
        let submanagerFiles = UserService.shared.toxMananger!.files
        submanagerFiles.retrySendingFile(message) { [weak self] error in
            guard let self = self else { return }
            
            let error = error as NSError
            if error.domain == kOCTManagerErrorDomain, error.code == OCTSendFileError.offlineFileTooBig.rawValue {
                self.errors.onNext(NSLocalizedString("Only offline files smaller than 10M are supported", comment: ""))
            } else if let errorMessage = error.localizedFailureReason {
                self.errors.onNext(errorMessage)
            }
        }
    }
    
    func checkGroupStatus() -> Bool {
        guard chat.isGroup else {
            return true
        }
        if chat.groupStatus == 1 {
            self.errors.onNext(NSLocalizedString("You were removed from this group", comment: ""))
            return false
        }
        if chat.groupStatus == 2 {
            self.errors.onNext(NSLocalizedString("Group was dissolved", comment: ""))
            return false
        }
        
        return true
    }
    
    private func buildAudioFileName(_ duration: Int) -> String {
        return "\(UUID().uuidString)_\(duration).\(audioExtension)"
    }
    
    func resendMessage(index: Int) {
        let message = messageList[index]
        guard message.isOutgoing else {
            return
        }
        
        switch message.kind {
        case .text(let text):
            if message.message.messageText?.status == 2 {
                deleteMessage(index: index)
                addTextMessage(text)
                hasResend = true
            }
        case .photo, .video, .file, .audio:
            resendFile(message: message.message)
            hasResend = false // don't force scroll to bottom
        default:
            return
        }
    }
    
    func deleteMessage(index: Int) {
        let message = messageList[index]
        UserService.shared.toxMananger!.chats.removeMessages([message.message], withoutNotifying: nil)
    }
    
    func handleFileMessageOperation(index: Int, status: FileTransferProgress) -> Bool {
        let model = messageList[index]
        
        let cancelBlock = {
            try? UserService.shared.toxMananger!.files.cancelFileTransfer(model.message)
        }
        
        if status == .waiting {
            if model.isOutgoing {
                resendMessage(index: index)
            } else {
                UserService.shared.toxMananger!.files.acceptFileTransfer(model.message, failureBlock: { [weak self] error in
                    guard let self = self else { return }
                    
                    let error = error as NSError
                    if let errorMessage = error.localizedFailureReason {
                        self.errors.onNext(errorMessage)
                    }
                })
            }
            return true
        }
        
        if case .loading = status {
            cancelBlock()
            return true
        }
        
        return false
    }
}

extension ConversationDataSource {
    func markAllMessageAsRead() {
        UserService.shared.toxMananger!.chats.markChatMessages(asRead: chat)
    }
    
    func convertModel(model: OCTMessageAbstract) -> MessageModel {
        let fileStorage = UserService.shared.toxMananger!.configuration().fileStorage
        let sender = model.isOutgoing() ? self.sender : Sender(id: model.senderUniqueIdentifier!, displayName: getName(messageAbstract: model))
        return MessageModel(model: model, sender: sender, fileStorage: fileStorage)
    }
}

extension ConversationDataSource: MessagesDataSource {
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }
    
    func currentSender() -> Sender {
        return sender
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }
}

public extension UICollectionView {
    
    /// Animate reload in a batch update
    ///
    /// - Parameters:
    ///   - changes: The changes from diff
    ///   - section: The section that all calculated IndexPath belong
    ///   - updateData: Update your data source model
    ///   - completion: Called when operation completes
    func reloadSections<T: DiffAware>(
        changes: [Change<T>],
        updateData: () -> Void,
        completion: ((Bool) -> Void)? = nil) {
        
        let changesWithIndexPath = IndexPathConverter().convert(changes: changes)
        
        performBatchUpdates({
            updateData()
            insideUpdate(changesWithIndexPath: changesWithIndexPath)
        }, completion: { finished in
            completion?(finished)
        })
        
        // reloadRows needs to be called outside the batch
        outsideUpdate(changesWithIndexPath: changesWithIndexPath)
    }
    
    // MARK: - Helper
    
    private func insideUpdate(changesWithIndexPath: ChangeWithIndexPath) {
        changesWithIndexPath.deletes.executeIfPresent {
            //      deleteItems(at: $0)
            let indexSet = IndexSet($0.map { $0.section })
            deleteSections(indexSet)
        }
        
        changesWithIndexPath.inserts.executeIfPresent {
            //      insertItems(at: $0)
            let indexSet = IndexSet($0.map { $0.section })
            insertSections(indexSet)
        }
        
        changesWithIndexPath.moves.executeIfPresent {
            $0.forEach { move in
                moveItem(at: move.from, to: move.to)
            }
        }
    }
    
    private func outsideUpdate(changesWithIndexPath: ChangeWithIndexPath) {
        changesWithIndexPath.replaces.executeIfPresent {
            self.reloadItems(at: $0)
        }
    }
}

public class IndexPathConverter {
    
    public init() {}
    
    public func convert<T>(changes: [Change<T>]) -> ChangeWithIndexPath {
        let inserts = changes.compactMap({ $0.insert }).map({ $0.index.toIndexPath() })
        let deletes = changes.compactMap({ $0.delete }).map({ $0.index.toIndexPath() })
        let replaces = changes.compactMap({ $0.replace }).map({ $0.index.toIndexPath() })
        let moves = changes.compactMap({ $0.move }).map({
            (
                from: $0.fromIndex.toIndexPath(),
                to: $0.toIndex.toIndexPath()
            )
        })
        
        return ChangeWithIndexPath(
            inserts: inserts,
            deletes: deletes,
            replaces: replaces,
            moves: moves
        )
    }
}

extension Int {
    
    fileprivate func toIndexPath() -> IndexPath {
        return IndexPath(row: 0, section: self)
    }
}
