//
//  ConversationViewController.swift
//  Tok
//
//  Created by Bryce on 2019/5/15.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions
import HXPhotoPicker
import SnapKit
import RxSwift
import RxCocoa

class ConversationViewController: BaseChatViewController {

    private let disposeBag = DisposeBag()
    
    private let indicatorView: ActivityIndicatorView = {
        let indicatorView = ActivityIndicatorView()
        indicatorView.tintColor = UIColor.tokFootnote
        return indicatorView
    }()
    
    private var messageSender: MessagesSender!
    private let messagesSelector = MessagesSelector()
    
    var dataSource: ConversationDataSource! {
        didSet {
            self.chatDataSource = self.dataSource
            self.messageSender = self.dataSource.messageSender
        }
    }
    
    private lazy var baseMessageHandler: BaseMessageHandler = {
        return BaseMessageHandler(dataSource: self.dataSource, messagesSelector: self.messagesSelector, parentViewController: self)
    }()
    
    private lazy var titleView: ConversationTitleView = {
        return ConversationTitleView(chat: dataSource.chat, messageService: dataSource.messageService)
    }()
    
    private let showScrollToBottomButtonThreshold: CGFloat = 150
    private lazy var scrollToBottomButton: UIButton = {
        let button = UIButton()
        button.alpha = 0
        button.setImage(UIImage(named: "ScrollToBottom"), for: .normal)
        button.addTarget(self, action: #selector(self.didClickScrollToBottom), for: .touchUpInside)
        return button
    }()
    
    private lazy var cameraViewController: CameraViewController = {
        let cameraViewController = CameraViewController()
        cameraViewController.modalPresentationStyle = .fullScreen
        
        cameraViewController.didSendImage = { [weak self] image in
            self?.dataSource.addPhotoMessage(image, isOriginal: false)
            self?.dismiss(animated: true, completion: nil)
        }
        cameraViewController.didSendFile = { [weak self] url in
            self?.dataSource.addVideoMessage(url)
            self?.dismiss(animated: true, completion: nil)
        }
        
        return cameraViewController
    }()
    
    private lazy var photoPicker: HXPhotoManager = {
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
    
    init() {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        hidesBottomBarWhenPushed = true
        updatesConfig.fastUpdates = false
        constants.autoloadingFractionalThreshold = 0.15
        MessageMenuItemPresenter.setupCustomMenus()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = titleView
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        if chatIsEnable() {
            let barButton = UIBarButtonItem(image: UIImage(named: "NavbarMore"), style: .plain, target: self, action: #selector(self.didClickMore))
            navigationItem.rightBarButtonItem = barButton
        }
        
        collectionView?.backgroundColor = UIColor.bma_color(rgb: 0xF2F2F5)
        
        view.addSubview(scrollToBottomButton)
        scrollToBottomButton.snp.makeConstraints { (make) in
            make.size.equalTo(44)
            make.trailing.equalTo(-5)
            make.bottom.equalTo(inputBarContainer.snp.top).offset(-5)
        }
        
        if dataSource.chat.isGroup {
            view.addSubview(indicatorView)
            indicatorView.snp.makeConstraints { (make) in
                make.top.equalTo(10)
                make.centerX.equalToSuperview()
            }
        }
        
        messagesSelector.delegate = self
        chatItemsDecorator = ChatItemsDecorator(messagesSelector: messagesSelector, isGroup: dataSource.chat.isGroup)
        
        dataSource.markAllMessageAsRead()
        dataSource.fetchGroupInfoIfNeeded()
        
        bindData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dataSource.markAllMessageAsRead()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AudioManager.shared.stop(deactivateAudioSession: true)
    }
    
    deinit {
        print("\(self) deinit")
    }
    
    // MARK: - Override
    
    private var chatInputPresenter: ExpandableChatInputBarPresenter?
    override func createChatInputView() -> UIView {
        let chatInputView = ChatInputBar.loadNib()
        chatInputView.isGroup = dataSource.chat.isGroup
        chatInputView.delegate = self
        
        let chatInputPresenter = ExpandableChatInputBarPresenter(
            inputPositionController: self,
            chatInputBar: chatInputView)
        self.chatInputPresenter = chatInputPresenter
        self.keyboardEventsHandler = chatInputPresenter
        self.scrollViewEventsHandler = chatInputPresenter
        
        chatInputView.textView.text = dataSource.enteredText
        chatInputView.textView.rx.didChange
            .throttle(.milliseconds(500), scheduler: MainScheduler.instance)
            .debug("didChange")
            .subscribe(onNext: { [unowned self] _ in
                let enteredText = chatInputView.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.dataSource.change(enterdText: enteredText)
            })
            .disposed(by: disposeBag)
        
        dataSource.longPressAvatar
            .asDriver(onErrorJustReturn: "")
            .drive(onNext: { [unowned self] atName in
                let enteredText = chatInputView.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !enteredText.contains(atName) else {
                    return
                }
                if enteredText.isEmpty {
                    chatInputView.textView.text = atName + " "
                } else {
                    chatInputView.textView.text = enteredText + " " + atName + " "
                }
                
                chatInputView.textView.becomeFirstResponder()
                self.scrollToBottom(animated: false)
            })
            .disposed(by: disposeBag)
        
        return chatInputView
    }
    
    override func createPresenterBuilders() -> [ChatItemType : [ChatItemPresenterBuilderProtocol]] {
        let baseMessageStyle = BaseMessageStyle()
        
        let messageViewModelBuilder = MessageViewModelDefaultBuilder(messageService: dataSource.messageService)
        
        let textMessageHandler = TextMessageHandler(dataSource: dataSource, messagesSelector: messagesSelector, parentViewController: self)
        let textMessagePresenter = TextMessagePresenterBuilder(viewModelBuilder: TextMessageViewModelBuilder(messageViewModelBuilder), interactionHandler: GenericMessageHandler(baseHandler: textMessageHandler))
        textMessagePresenter.baseMessageStyle = baseMessageStyle
        textMessagePresenter.textCellStyle = TextMessageStyle(baseStyle: baseMessageStyle)
        
        let mediaMessageHandler = MediaMessageHandler(dataSource: dataSource, messagesSelector: messagesSelector, parentViewController: self)
        mediaMessageHandler.delegate = self
        let photoMessagePresenter = PhotoMessagePresenterBuilder(viewModelBuilder: PhotoMessageViewModelBuilder(messageViewModelBuilder), interactionHandler: GenericMessageHandler(baseHandler: mediaMessageHandler))
        photoMessagePresenter.baseCellStyle = baseMessageStyle
        photoMessagePresenter.photoCellStyle = PhotoMessageStyle(baseStyle: baseMessageStyle)
        
        let videoMessagePresenter = VideoMessagePresenterBuilder(viewModelBuilder: VideoMessageViewModelBuilder(messageViewModelBuilder), interactionHandler: GenericMessageHandler(baseHandler: mediaMessageHandler))
        videoMessagePresenter.baseCellStyle = baseMessageStyle
        videoMessagePresenter.bubbleCellStyle = VideoBubbleViewStyle()
        
        let audioMessageHandler = AudioMessageHandler(dataSource: dataSource, messagesSelector: messagesSelector, parentViewController: self)
        let audioMessagePresenter = AudioMessagePresenterBuilder(viewModelBuilder: AudioMessageViewModelBuilder(messageViewModelBuilder), interactionHandler: GenericMessageHandler(baseHandler: audioMessageHandler))
        audioMessagePresenter.baseCellStyle = baseMessageStyle
        audioMessagePresenter.audioCellStyle = AudioBubbleViewStyle()
        
        let fileMessageHandler = FileMessageHandler(dataSource: dataSource, messagesSelector: messagesSelector, parentViewController: self)
        fileMessageHandler.delegate = self
        let fileMessagePresenter = FileMessagePresenterBuilder(viewModelBuilder: FileMessageViewModelBuilder(messageViewModelBuilder), interactionHandler: GenericMessageHandler(baseHandler: fileMessageHandler))
        fileMessagePresenter.baseCellStyle = baseMessageStyle
        
        let callMessagePresenter = CallMessagePresenterBuilder(viewModelBuilder: CallMessageViewModelBuilder(messageViewModelBuilder), interactionHandler: GenericMessageHandler(baseHandler: baseMessageHandler))
        callMessagePresenter.baseCellStyle = baseMessageStyle
        
        let systemMessagePresenter = SystemMessagePresenterBuilder()
        systemMessagePresenter.interactionHandler = self
        
        return [
            TextMessageModel.chatItemType: [textMessagePresenter],
            PhotoMessageModel.chatItemType: [photoMessagePresenter],
            AudioMessageModel.chatItemType: [audioMessagePresenter],
            FileMessageModel.chatItemType: [fileMessagePresenter],
            VideoMessageModel.chatItemType: [videoMessagePresenter],
            CallMessageModel.chatItemType: [callMessagePresenter],
            TimeSeparatorModel.chatItemType: [TimeSeparatorPresenterBuilder()],
            TipMessageModel.chatItemType: [TipMessagePresenterBuilder()],
            SystemMessageModel.chatItemType: [systemMessagePresenter]
        ]
    }
    
    override func userDidTapOnCollectionView() {
        super.userDidTapOnCollectionView()

        chatInputPresenter?.onDidEndEditing(force: true)
    }
    
    override func loadMoreContentIfNeeded() {
        guard dataSource.pageLoading.value == false else { return }
        if self.isCloseToTop() {
            dataSource.pullMessageIfNeeded(up: true)
        }
    }
    
    // MARK: - BindData
    
    private func bindData() {
        if dataSource.chat.isGroup {
            autoLoadingEnabled = false
        } else {
            autoLoadingEnabled = true
        }
        
        dataSource.pageLoading
            .subscribe(onNext: { [weak self] loading in
                guard let self = self else { return }
                if loading {
                    self.indicatorView.startAnimating()
                } else {
                    self.indicatorView.stopAnimating()
                }
            })
            .disposed(by: disposeBag)
        
        collectionView?.rx.didScroll
            .asDriver()
            .skip(2)
            .drive(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.updateScrollToBottomButton()
                self.updateIndicatorView()
                self.dataSource.scrollAtBottom = self.isScrolledAtBottom()
            })
            .disposed(by: disposeBag)
    }
    
    func updateScrollToBottomButton() {
        guard let collectionView = collectionView else { return }
        let animationDuration = 0.1
        let position = collectionView.contentSize.height - collectionView.contentOffset.y - collectionView.bounds.height
        let didReachThreshold = position > showScrollToBottomButtonThreshold
        let shouldShowScrollToBottomButton = didReachThreshold
        if scrollToBottomButton.alpha < 0.1 && shouldShowScrollToBottomButton {
            UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseOut, animations: {
                self.scrollToBottomButton.transform = CGAffineTransform(scaleX: 1, y: 1)
                self.scrollToBottomButton.alpha = 1
            })
        } else if scrollToBottomButton.alpha > 0.9 && !shouldShowScrollToBottomButton {
            UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseOut, animations: {
                self.scrollToBottomButton.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                self.scrollToBottomButton.alpha = 0
            })
        }
    }
    
    func updateIndicatorView() {
        guard dataSource.pageLoading.value else { return }
        guard let collectionView = collectionView else { return }
        guard collectionView.contentSize.height > 0 else { return }
        let needShow = (self.visibleRect().minY / collectionView.contentSize.height) < 0.05
        if needShow {
            indicatorView.alpha = 1
        } else {
            indicatorView.alpha = 0
        }
    }
}

extension ConversationViewController {
    fileprivate func chatIsEnable() -> Bool {
        guard dataSource.chat.isGroup else {
            return true
        }
        return dataSource.chat.groupStatus == 0
    }
    
    @objc
    func didClickMore() {
        if dataSource.chat.isGroup {
            guard dataSource.chat.groupStatus == 0 else {
                return
            }
            
            let vc = GroupDetailViewController(chat: dataSource.chat, messageService: dataSource.messageService)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            guard let friend = dataSource.chat.friends?.firstObject() as? OCTFriend else {
                return
            }
            
            let vc = FriendViewController(messageService: dataSource.messageService, friendPublicKey: friend.publicKey)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc
    func didClickScrollToBottom() {
        dataSource.pullTailMessages()
        scrollToBottom(animated: true)
    }
}

extension ConversationViewController: MessagesSelectorDelegate {
    func messagesSelector(_ messagesSelector: MessagesSelector, didSelectMessage: MessageModelProtocol) {
        self.enqueueModelUpdate(updateType: .normal)
    }
    
    func messagesSelector(_ messagesSelector: MessagesSelector, didDeselectMessage: MessageModelProtocol) {
        self.enqueueModelUpdate(updateType: .normal)
    }
}

extension ConversationViewController: ChatInputBarDelegate {
    
    var menuDelegate: ChatMoreActionViewDelegate? {
        return self
    }
    
    func onSendButtonPressed(text: String) {
        dataSource.addTextMessage(text)
    }

    func onSendAudioMessage(url: URL, duration: UInt) {
        dataSource.addAudioMessage(url: url, duration: duration)
    }
}

extension ConversationViewController: ChatMoreActionViewDelegate {
    
    func chatShareMoreViewPhotoTaped() {
        photoPicker.clearSelectedList()
        
        self.hx_presentSelectPhotoController(with: photoPicker, didDone: { (_, photoList, videoList, isOriginal, _, manager) in
            if let photoList = photoList {
                photoList.forEach { model in
                    switch model.type {
                    case .photoGif:
                        if let fileURL = model.fileURL {
                            let fileName = UUID().uuidString
                            let destinationPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension(fileURL.pathExtension)
                            do {
                                try FileManager.default.copyItem(at: fileURL, to: destinationPath)
                                self.dataSource.addFileMessage(url: destinationPath)
                            } catch {
                                print("😱😱😱Move GIF Failed. \(fileURL)")
                            }
                        }
                    default:
                        ([model] as NSArray).hx_requestImage(withOriginal: isOriginal, completion: { (imageList, _) in
                            imageList?.forEach { image in
                                self.dataSource.addPhotoMessage(image, isOriginal: isOriginal)
                            }
                        })
                    }
                }
            }
            
            if let videoList = videoList as NSArray? {
                videoList.forEach { model in
                    guard let model = model as? HXPhotoModel else { return }
                    
                    ProgressHUD.showLoadingHUD(in: self.view)
                    model.requestAVAssetStartRequestICloud(nil, progressHandler: nil, success: { (asset, _, _, _) in
                        guard let videoAsset = asset as? AVURLAsset else {
                            return
                        }
                        
                        let fileName = (UUID().uuidString as NSString).appendingPathExtension(videoAsset.url.pathExtension)!
                        let tempDestinationPath = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName))
                        do {
                            try FileManager.default.copyItem(at: videoAsset.url, to: tempDestinationPath)
                            DispatchQueue.main.async {
                                self.dataSource.addVideoMessage(tempDestinationPath)
                            }
                        } catch {
                            print("Export Error")
                        }
                        ProgressHUD.hideLoadingHUD(in: self.view)
                    }, failed: { (_, _) in
                        ProgressHUD.hideLoadingHUD(in: self.view)
                    })
                }
            }
        }) { (_, manager) in
            manager?.clearSelectedList()
        }
    }
    
    func chatShareMoreViewCameraTaped() {
        present(cameraViewController, animated: true, completion: nil)
    }
    
    func chatShareMoreViewFileTaped() {
        let vc = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .import)
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
    
    func chatShareMoreViewAudioCallTaped() {
        NotificationCenter.default.post(name: NSNotification.Name.StartVoiceCall, object: nil, userInfo: ["chat": self.dataSource.chat])
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

extension ConversationViewController: MediaMessageHandlerDelegate {
    func mediaMessageHandler(sourceViewForMessageBy id: String) -> UIImageView? {
        let imageView = collectionView?.visibleCells
            .compactMap { cell -> UIImageView? in
                if let currentCell = cell as? PhotoMessageCollectionViewCell, currentCell.messageViewModel.messageModel.uid == id {
                    return currentCell.bubbleView.imageView
                }
                if let currentCell = cell as? VideoMessageCollectionViewCell, currentCell.messageViewModel.messageModel.uid == id {
                    return currentCell.bubbleView.imageView
                }
                return nil
            }
            .first
        
        return imageView
    }
}

extension ConversationViewController: SystemMessageHandler {
    func userDidTapOnBubble() {
        presentPrivacy()
    }
}

// MARK: - UIDocumentInteractionControllerDelegate

extension ConversationViewController: FileMessageHandlerDelegate {
    func openDocumentAction(filePath: String, name: String?) {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return
        }
        
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController!.name = name
        previewDocumentController!.delegate = self
        if !previewDocumentController!.presentPreview(animated: true) {
            previewDocumentController!.presentOpenInMenu(from: CGRect.zero, in: view, animated: true)
        }
    }
}

extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        previewDocumentController = nil
    }
}
