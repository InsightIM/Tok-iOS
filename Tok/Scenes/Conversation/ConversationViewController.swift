//
//  ConversationViewController.swift
//  Tok
//
//  Created by Bryce on 2018/9/10.
//  Copyright © 2018年 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Action
import SnapKit
import SwiftDate
import SafariServices
import HXPhotoPicker

struct AvatarConstants {
    static let CornerRadius: CGFloat = 4.0
}

class ConversationViewController: MessagesViewController {

    let dataSource: ConversationDataSource
    let disposeBag = DisposeBag()
    
    var photoMessages: Results<OCTMessageAbstract>?
    
    var kCustomKeyboardHeight: CGFloat = 216
    
    /// ActionBar orginal height
    var kChatActionBarOriginalHeight: CGFloat {
        return 60 + UIApplication.safeAreaInsets.bottom
    }
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        return refreshControl
    }()
    
    lazy var cameraViewController = CameraViewController()
    
    lazy var photoPicker: HXPhotoManager = {
        let manager = HXPhotoManager(type: .photoAndVideo)!
        manager.configuration.openCamera = false
        manager.configuration.lookLivePhoto = true
        manager.configuration.photoMaxNum = 9
        manager.configuration.videoMaxNum = 9
        manager.configuration.maxNum = 9
        manager.configuration.saveSystemAblum = false
        manager.configuration.showDateSectionHeader = false
        manager.configuration.hideOriginalBtn = false
        manager.configuration.photoCanEdit = true
        
        return manager
    }()
    
    private var previewDocumentController: UIDocumentInteractionController?
    
    private lazy var backgroudImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "ChatBg")
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private let titleView = ConversationTitleView()
    
    override var inputAccessoryView: UIView? {
        return nil
    }
    
    private let linkAttributes: [NSAttributedString.Key : Any] = [
        NSAttributedString.Key.foregroundColor: UIColor.tokLink,
        NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
        NSAttributedString.Key.underlineColor: UIColor.tokLink
    ]
    
    private let linkWithoutUnderlineAttributes: [NSAttributedString.Key : Any] = [
        NSAttributedString.Key.foregroundColor: UIColor.tokLink
    ]
    
    var currentIndex: UInt = 0
    weak var selectedImageView: UIImageView?
    
    var chatActionBarView: ChatActionBarView!
    var actionBarPaddingBottomConstranit: Constraint?
    var keyboardHeightConstraint: NSLayoutConstraint?
    var emotionInputView: ChatEmotionInputView!
    var shareMoreView: ChatShareMoreView!
    var keyboardDuration: Double = 0.25
    var keyboardCurve: UInt = 0
    
    var willMove: Bool = false
    
    init(chat: OCTChat) {
        dataSource = ConversationDataSource(chat: chat)
        
        super.init(nibName: nil, bundle: nil)
        
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
    
    override func viewDidLoad() {
        let layout = ConversationCollectionViewFlowLayout()
        messagesCollectionView = MessagesCollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        }
        
        navigationItem.titleView = titleView
        
        messagesCollectionView.register(StatusTextMessageCell.self)
        messagesCollectionView.register(PhotoMessageCell.self)
        messagesCollectionView.register(VideoMessageCell.self)
        messagesCollectionView.register(FileMessageCell.self)
        messagesCollectionView.register(AudioOutgoingCell.self)
        messagesCollectionView.register(AudioIncomingCell.self)
        messagesCollectionView.register(CallMessageCell.self)
        messagesCollectionView.register(TipMessageCell.self)

        scrollsToBottomOnKeyboardBeginsEditing = true
        maintainPositionOnKeyboardFrameChanged = true
        
        messagesCollectionView.messagesDataSource = dataSource
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        
        messagesCollectionView.backgroundColor = UIColor("#F2F2F5")
//        messagesCollectionView.backgroundView = backgroudImageView
        
        messagesCollectionView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(loadMoreMessages), for: .valueChanged)
        
        setupSubviews(self)
        keyboardControl()
        setupActionBarButtonInterAction()
        setupMenus()
        
        bindDataSource()
        
        chatActionBarView.inputTextView.text = dataSource.chat.enteredText ?? ""
        
        dataSource.markAllMessageAsRead()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        initViewLayout()
        willMove = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        dataSource.markAllMessageAsRead()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        FCAudioPlayer.shared().stop(withAudioSessionDeactivated: true)
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        willMove = parent == nil
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        willMove = false
    }
    
    // MARK: - Private
    
    private var didInitViewLayout = false
    
    private func initViewLayout() {
        if !didInitViewLayout {
            didInitViewLayout = true
            
            controlExpandableInputView(showExpandable: true, forceUpdate: false, animation: false, scrollToBottom: false)
            initScrollToBottom()
        }
    }
    
    private func initScrollToBottom() {
        let navigateBarHeight: CGFloat = 44
        let bottomOffset = CGPoint(x: 0.0, y: max(0.0, messagesCollectionView.contentSize.height - messagesCollectionView.height + UIApplication.safeAreaInsets.top + navigateBarHeight))
        messagesCollectionView.setContentOffset(bottomOffset, animated: false)
    }
    
    private func bindDataSource() {
        dataSource.errors
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                ProgressHUD.showTextHUD(withText: message, in: self?.view)
            })
            .disposed(by: disposeBag)
        
        dataSource.hasMore
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] hasMore in
                if hasMore == false {
                    self?.refreshControl.removeFromSuperview()
                }
            })
            .disposed(by: disposeBag)
        
        dataSource.titleUpdated
            .distinctUntilChanged { $0.0 == $1.0 && $0.1 == $1.1 }
            .debug("titleUpdated")
            .subscribe(onNext: { [weak self] (title, subtitle, userStatus) in
                guard let `self` = self else { return }
                self.titleView.update(title: title, subtitle: subtitle, userStatus: userStatus)
            })
            .disposed(by: disposeBag)
        
        dataSource.batchUpdates
            .subscribe(onNext: { [weak self] (inserts, modifies, deletes, forceToBottom) in
                guard let `self` = self else { return }
                
                var isAtBottom: Bool {
                    let bottomOffset = self.messagesCollectionView.contentSize.height - self.messagesCollectionView.bounds.size.height
                    let diff = bottomOffset - self.messagesCollectionView.contentOffset.y
                    return diff < 80
                }
                
                self.messagesCollectionView.performBatchUpdates({
                    self.messagesCollectionView.deleteSections(deletes)
                    self.messagesCollectionView.insertSections(inserts)
                    self.messagesCollectionView.reloadItems(at: modifies)
                }, completion: { _ in
                    if forceToBottom {
                        self.messagesCollectionView.scrollToBottom(animated: true)
                    }
                })
                
                let lastVisible = self.messagesCollectionView.indexPathsForVisibleItems.contains(IndexPath(item: 0, section: self.dataSource.messageList.count - 1))
                if !forceToBottom && inserts.count > 0 && (isAtBottom || lastVisible) {
                    self.messagesCollectionView.scrollToBottom(animated: true)
                }
            })
            .disposed(by: disposeBag)
        
        messagesCollectionView.rx.contentOffset
            .skip(2)
            .filter { [weak self] _ in
                return self?.dataSource.hasMore.value == true
            }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] offset in
                guard let self = self, self.dataSource.hasMore.value else { return }
                if offset.y < -self.refreshControl.frame.height, self.refreshControl.isRefreshing == false {
                    self.refreshControl.beginRefreshing()
                    self.loadMoreMessages()
                }
            })
            .disposed(by: disposeBag)
        
        chatActionBarView.inputTextView.rx.didChange
            .subscribe(onNext: { [unowned self] _ in
                let enteredText = self.chatActionBarView.inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
                UserService.shared.toxMananger!.objects.change(self.dataSource.chat, enteredText: enteredText)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - ScrollViewDelegate
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        hideAllKeyboard()
    }
    
    // MARK: - Helpers
    
    @objc
    private func loadMoreMessages() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            DispatchQueue.main.async {
                self.dataSource.loadData()
                self.messagesCollectionView.reloadDataAndKeepOffset()
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    // MARK: - Document
    
    private func openDocumentAction(filePath: String?) {
        guard let filePath = filePath else {
            return
        }
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return
        }
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController?.delegate = self
        if !(previewDocumentController?.presentPreview(animated: true) ?? false) {
            previewDocumentController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        }
    }
    
    // MARK: - CollectionView DataSource
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let model = dataSource.messageList[indexPath.section]
        switch model.kind {
        case .text, .attributedText, .emoji:
            let cell: StatusTextMessageCell = collectionView.dequeueReusableCell(for: indexPath)
            cell.configure(with: model, at: indexPath, and: messagesCollectionView)
            cell.bind(with: model)
            return cell
        case .photo(let item):
            let cell: PhotoMessageCell = collectionView.dequeueReusableCell(for: indexPath)
            
            cell.configure(with: model, at: indexPath, and: collectionView as! MessagesCollectionView)
            cell.bind(with: item as! MediaModel)
            
            return cell
        case .video(let item):
            let cell: VideoMessageCell = collectionView.dequeueReusableCell(for: indexPath)
            
            cell.configure(with: model, at: indexPath, and: collectionView as! MessagesCollectionView)
            cell.bind(with: item as! MediaModel)
            
            return cell
        case .system(let info):
            let cell: TipMessageCell = collectionView.dequeueReusableCell(for: indexPath)
            cell.textLabel.text = info
            cell.linkTipButton.rx.action = CocoaAction { [unowned self] in
                self.presentPrivacy()
                return .empty()
            }
            return cell
        case .audio(let item):
            let cell = model.isOutgoing
                ? collectionView.dequeueReusableCell(for: indexPath, cellType: AudioOutgoingCell.self)
                : collectionView.dequeueReusableCell(for: indexPath, cellType: AudioIncomingCell.self)
            
            cell.configure(with: model, at: indexPath, and: collectionView as! MessagesCollectionView)
            cell.bind(with: item as! AudioMessageModel)
            
            return cell
        case .file(let item):
            let cell: FileMessageCell = collectionView.dequeueReusableCell(for: indexPath)
            
            cell.configure(with: model, at: indexPath, and: collectionView as! MessagesCollectionView)
            cell.bind(with: item as! FileMessageModel)
            
            return cell
        case .custom(let item):
            guard item is CallMessageItem else {
                fallthrough
            }
            
            let cell: CallMessageCell = collectionView.dequeueReusableCell(for: indexPath)
            cell.configure(with: model, at: indexPath, and: collectionView as! MessagesCollectionView)
            
            return cell
        default:
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let model = dataSource.messageList[indexPath.section]
        if model.message.readed,
            model.isOutgoing {
                return
        }
        
        DispatchQueue.main.async {
            UserService.shared.toxMananger!.chats.setMessageReaded(model.message)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if case .system = dataSource.messageList[section].kind {
            return .zero
        }
        return UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    }
    
    // MARK: - CollectionView Menu
    
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else { return false }
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        
        switch message.kind {
        case .text, .attributedText, .emoji, .photo, .video, .audio, .file:
            selectedIndexPathForMenu = indexPath
            return true
        case .custom, .location, .system:
            return false
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        let model = dataSource.messageList[indexPath.section]
        
        if model.isOutgoing == false, model.status == .failed {
            switch model.kind {
            case .text, .attributedText, .emoji:
                return (action == NSSelectorFromString("copy:"))
                    || (action == NSSelectorFromString("deleteMessage:"))
            default:
                return action == NSSelectorFromString("deleteMessage:")
            }
        }
        
        if case .audio = model.kind {
            return action == NSSelectorFromString("deleteMessage:")
        }
        
        return (action == NSSelectorFromString("copy:"))
            || (action == NSSelectorFromString("forward:"))
            || (action == NSSelectorFromString("deleteMessage:"))
    }
    
    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
        if action == NSSelectorFromString("copy:") {
            return super.collectionView(collectionView, performAction: action, forItemAt: indexPath, withSender: sender)
        } else if action == NSSelectorFromString("forward:") {
            let message = dataSource.messageList[indexPath.section]
            let viewModel = ForwardMessageViewModel(message: message)
            let vc = ForwardChatViewController(viewModel: viewModel)
            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true, completion: nil)
        } else if action == NSSelectorFromString("deleteMessage:") {
            dataSource.deleteMessage(index: indexPath.section)
        }
    }
}

// MARK: - MessagesDisplayDelegate

extension ConversationViewController: MessagesDisplayDelegate {
    
    // MARK: - Text Messages
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return .black
    }
    
    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        switch detector {
        case .command, .hashtag:
            return linkWithoutUnderlineAttributes
        default:
            return linkAttributes
        }
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        if dataSource.isFindFriendBot() {
            return [.url, .address, .phoneNumber, .command, .hashtag, .custom(tokIdRegex)]
        }
        return [.url, .address, .phoneNumber, .hashtag, .custom(tokIdRegex)]
    }
    
    // MARK: - All Messages
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        if case .file = message.kind {
            return .tokIncoming
        }
        return dataSource.isFromCurrentSender(message: message) ? .tokOutgoing : .tokIncoming
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        switch message.kind {
        case .photo, .video:
            return .bubble
        default:
            let corner: MessageStyle.TailCorner = dataSource.isFromCurrentSender(message: message) ? .topRight : .topLeft
            return .bubbleTail(corner, .pointedEdge)
        }
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let image = dataSource.isFromCurrentSender(message: message) ? UserService.shared.avatarImage : dataSource.avatarFor(indexPath: indexPath)
        avatarView.set(avatar: Avatar(image: image, initials: "?"))
        avatarView.setCorner(radius: AvatarConstants.CornerRadius)
    }
    
    func configureAccessoryView(_ accessoryView: UIView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        // Cells are reused, so only add a button here once. For real use you would need to
        // ensure any subviews are removed if not needed
        
        let model = dataSource.messageList[indexPath.section]
        guard (model.status == .failed || model.status == .unread) else {
            accessoryView.isHidden = true
            return
        }
        
        let button = accessoryView.subviews.first as? UIButton ?? UIButton()
        button.setImage(UIImage(named: model.status.imageName), for: .normal)
        accessoryView.addSubview(button)
        button.frame = accessoryView.bounds
        button.isUserInteractionEnabled = false // respond to accessoryView tap through `MessageCellDelegate`
        accessoryView.layer.cornerRadius = accessoryView.frame.height / 2
        accessoryView.isHidden = false
    }
}

// MARK: - MessagesLayoutDelegate

extension ConversationViewController: MessagesLayoutDelegate {
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if case .system = message.kind {
            return 0
        }
        
        if indexPath.section == 0 {
            return 40
        }
        
        if let minute = (message.sentDate - dataSource.messageList[indexPath.section - 1].sentDate).minute, minute >= 3 {
            return 40
        }
        
        return 0
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if dataSource.chat.isGroup, !dataSource.isFromCurrentSender(message: dataSource.messageList[indexPath.section]) {
            return 16
        }
        return 0
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 0
    }
    
}

// MARK: - MessageCellDelegate

extension ConversationViewController: MessageCellDelegate {
    
    internal func didClickAvatar(isOutgoing: Bool) {
        if isOutgoing {
            let vc = ProfileViewController()
            navigationController?.pushViewController(vc, animated: true)
        } else {
            guard let friend = dataSource.chat.friends?.firstObject() as? OCTFriend else {
                return
            }
            if dataSource.isFindFriendBot() {
                let vc = BotInfoViewController(bot: dataSource.findFriendBot)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                let vc = FriendViewController(friend: friend)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func didTapAvatar(in cell: MessageCollectionViewCell, indexPath: IndexPath) {
        let message = dataSource.messageList[indexPath.section]
        didClickAvatar(isOutgoing: message.isOutgoing)
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell, indexPath: IndexPath) {
        let model = dataSource.messageList[indexPath.section]
        
        switch model.kind {
        case .audio(let item):
            let audio = item as! AudioMessageModel
            let handled = dataSource.handleFileMessageOperation(index: indexPath.section, status: audio.status.value)
            if handled {
                return
            }
            
            if model.isOutgoing == false, audio.status.value != .success {
                return
            }
            
            guard let path = audio.path else {
                return
            }
            
            let cell = cell as! AudioMessageCell
            let cellIsPlaying = cell.isPlaying
            FCAudioPlayer.shared().stop(withAudioSessionDeactivated: cellIsPlaying)
            if !cellIsPlaying {
                cell.isPlaying = true
                FCAudioPlayer.shared().playFile(atPath: path) { [weak cell] (success, error) in
                    if let error = error as? FCAudioPlayerError, error == .cancelled {
                        DispatchQueue.main.async {
                            cell?.isPlaying = false
                        }
                    } else if let error = error {
                        print("\(error)")
                    }
                }
            }
            
            UserService.shared.toxMananger!.chats.setMessageFileOpened(model.message)
        case .photo(let item), .video(let item):
            let cell = cell as! OperationMessageCell
            let item = item as! MediaModel
            
            let handled = dataSource.handleFileMessageOperation(index: indexPath.section, status: item.status.value)
            if handled {
                return
            }
            
            if model.isOutgoing || (model.isOutgoing == false && model.status == .sent) {
                didTapPhotoOrVideo(message: model.message, imageView: cell.imageView)
            }
        case .file(let item):
            let item = item as! FileMessageModel
            let handled = dataSource.handleFileMessageOperation(index: indexPath.section, status: item.status.value)
            if handled {
                return
            }
            
            if model.isOutgoing || (model.isOutgoing == false && model.status == .sent) {
                openDocumentAction(filePath: item.path)
            }
        default:
            didTapBlankSpaceView()
        }
    }
    
    func didTapCellTopLabel(in cell: MessageCollectionViewCell, indexPath: IndexPath) {
        hideAllKeyboard()
    }
    
    func didTapMessageTopLabel(in cell: MessageCollectionViewCell, indexPath: IndexPath) {
        hideAllKeyboard()
    }
    
    func didTapMessageBottomLabel(in cell: MessageCollectionViewCell, indexPath: IndexPath) {
        hideAllKeyboard()
    }
    
    func didTapAccessoryView(in cell: MessageCollectionViewCell, indexPath: IndexPath) {
        let message = dataSource.messageList[indexPath.section]
        if message.status != .failed {
            didTapBlankSpaceView()
            return
        }
        
        let deleteAction: AlertViewManager.Action = { [weak self] in
            self?.dataSource.deleteMessage(index: indexPath.section)
            return ()
        }
        
        if message.isOutgoing {
            let resendAction: AlertViewManager.Action = { [weak self] in
                self?.dataSource.resendMessage(index: indexPath.section)
                return ()
            }
            
            AlertViewManager.showActionSheet(with: [
                (NSLocalizedString("Resend", comment: ""), .default, resendAction),
                (NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)
            ])
        } else {
            AlertViewManager.showActionSheet(with: [
                (NSLocalizedString("Delete", comment: ""), .destructive, deleteAction)
            ])
        }
    }
    
    func didTapBlankSpaceView() {
        hideAllKeyboard()
    }
    
    func didTapPhotoOrVideo(message: OCTMessageAbstract, imageView: UIImageView) {
        
        // UTI： https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "chatUniqueIdentifier == %@ AND messageFile != nil AND messageFile.fileUTI in { 'public.jpeg', 'public.png', 'public.fax', 'public.jpeg-2000', 'public.tiff', 'com.compuserve.gif', 'com.microsoft.bmp', 'com.microsoft.ico', 'public.mpeg-4', 'com.apple.quicktime-movie', 'public.movie', 'public.video', 'public.avi' }", dataSource.chat.uniqueIdentifier),
            
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "messageFile.fileType == \(OCTMessageFileType.ready.rawValue)"),
                NSPredicate(format: "senderUniqueIdentifier == nil AND messageFile.fileType == \(OCTMessageFileType.canceled.rawValue)"),
                ]),
            ])
        
        photoMessages = UserService.shared.toxMananger!.objects.messages(predicate: predicate).sortedResultsUsingProperty("dateInterval", ascending: true)
        
        let index = photoMessages!.indexOfObject(message)
        guard index < UInt.max else {
            return
        }
        currentIndex = index
        selectedImageView = imageView
        
        let browser = YBImageBrowser()
        browser.dataSource = self
        browser.currentIndex = currentIndex
        browser.show()
    }
}

extension ConversationViewController: YBImageBrowserDataSource {
    func yb_imageBrowserView(_ imageBrowserView: YBImageBrowserView, dataForCellAt index: UInt) -> YBImageBrowserCellDataProtocol {
        guard let messages = photoMessages,
            index < messages.count else {
                return YBImageBrowseCellData()
        }
        
        let message = messages[Int(index)]
        let model = dataSource.convertModel(model: message)
        let source: UIImageView? = currentIndex == index ? selectedImageView : nil
        
        if case .photo(let file) = model.kind {
            let cell = YBImageBrowseCellData()
            cell.imageBlock = { file.image }
            cell.sourceObject = source
            return cell
        } else if case .video(let file) = model.kind {
            let cell = YBVideoBrowseCellData()
            cell.url = file.url
            cell.sourceObject = source
            return cell
        }
        
        return YBImageBrowseCellData()
    }
    
    func yb_numberOfCell(for imageBrowserView: YBImageBrowserView) -> UInt {
        return UInt(photoMessages?.count ?? 0)
    }
}

// MARK: - MessageLabelDelegate

extension ConversationViewController: MessageLabelDelegate {
    func didSelectCommand(_ commandString: String) {
        let command = commandString.lowercased()
        guard command != FindFriendBotModel.Command.set.rawValue else {
            chatActionBarView.inputTextView.text = command + " " + (UserService.shared.toxMananger!.user.userStatusMessage() ?? "")
            return
        }
        
        dataSource.addTextMessage(command)
    }
    
    func didSelectPhoneNumber(_ phoneNumber: String) {
        if let url = URL(string: "tel://" + phoneNumber) {
            UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
        }
    }
    
    func didSelectURL(_ url: URL) {
        let vc = SFSafariViewController(url: url)
        self.present(vc, animated: true)
    }
    
    func didSelectCustom(_ pattern: String, match: String?) {
        if pattern == tokIdRegex.pattern, let address = match {
            let alertController = UIAlertController(title: NSLocalizedString("Confirm to send friend request", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField(configurationHandler: { textField in
                textField.text = String(format: NSLocalizedString("Hi, i'm %@", comment: ""), UserService.shared.nickName ?? "Tok User")
                textField.clearButtonMode = .whileEditing
            })

            let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak alertController] _ in
                guard let alertController = alertController, let textField = alertController.textFields?.first else { return }
                
                FriendService.sendRequest(address: address, message: textField.text ?? "")
                    .subscribe(onError: { [weak self] error in
                        ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
                    })
                    .disposed(by: self.disposeBag)
            }
            
            alertController.addAction(confirmAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ConversationViewController: UIDocumentPickerDelegate {
    
    @available(iOS 11.0, *)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard urls.count > 0 else {
            return
        }
        documentPicker(controller, didPickDocumentAt: urls[0])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        let previewViewController = FileSendViewController(documentUrl: url, dataSource: dataSource)
        navigationController?.pushViewController(previewViewController, animated: true)
    }
}

// MARK: - UIDocumentInteractionControllerDelegate
extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        previewDocumentController = nil
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}

let mediaDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = [.pad]
    formatter.unitsStyle = .positional
    return formatter
}()
