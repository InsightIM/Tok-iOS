//
//  ConversationViewController+Subviews.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import HXPhotoPicker

extension NSNotification.Name {
    static let StartVoiceCall = NSNotification.Name("StartVoiceCall")
    static let StartVideoCall = NSNotification.Name("StartVideoCall")
}

extension ConversationViewController {
    
    func setupSubviews(_ delegate: UITextViewDelegate) {
        setupActionBar(delegate)
        setupCollectionView()
        setupKeyboardInputView()
    }
    
    fileprivate func setupCollectionView() {
        messagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        messagesCollectionView.delegate = self
        view.addSubview(messagesCollectionView)
        messagesCollectionView.snp.makeConstraints { (make) -> Void in
            make.left.right.top.equalToSuperview()
            make.bottom.equalTo(self.chatActionBarView.snp.top)
        }
    }
    
    fileprivate func setupActionBar(_ delegate: UITextViewDelegate) {
        chatActionBarView = UIView.ts_viewFromNib(ChatActionBarView.self)
        chatActionBarView.delegate = self
        chatActionBarView.inputTextView.delegate = delegate
        chatActionBarView.recordButton.dataSource = dataSource
        view.addSubview(self.chatActionBarView)
        chatActionBarView.snp.makeConstraints { (make) -> Void in
            make.left.right.equalToSuperview()
            self.actionBarPaddingBottomConstranit = make.bottom.equalToSuperview().constraint
            make.height.equalTo(self.kChatActionBarOriginalHeight)
        }
    }
    
    fileprivate func setupKeyboardInputView() {
        // emotionInputView init
        emotionInputView = UIView.ts_viewFromNib(ChatEmotionInputView.self)
        emotionInputView.delegate = self
        view.addSubview(emotionInputView)
        emotionInputView.snp.makeConstraints { (make) -> Void in
            make.left.right.equalToSuperview()
            make.top.equalTo(chatActionBarView.snp.bottom).offset(0)
            make.height.equalTo(kCustomKeyboardHeight + UIApplication.safeAreaInsets.bottom)
        }
        
        // shareMoreView init
        shareMoreView = UIView.ts_viewFromNib(ChatShareMoreView.self)
        shareMoreView!.delegate = self
        shareMoreView!.isGroup = dataSource.chat.isGroup
        shareMoreView!.itemDataSouce = dataSource.chat.isGroup
            ? [
                (NSLocalizedString("Album", comment: ""), UIImage(named: "MenuAlbum")!),
                (NSLocalizedString("Camera", comment: ""), UIImage(named: "MenuCamera")!),
                (NSLocalizedString("File", comment: ""), UIImage(named: "MenuFile")!),
                ]
            : [
                (NSLocalizedString("Album", comment: ""), UIImage(named: "MenuAlbum")!),
                (NSLocalizedString("Camera", comment: ""), UIImage(named: "MenuCamera")!),
                (NSLocalizedString("Call", comment: ""), UIImage(named: "MenuCall")!),
                (NSLocalizedString("File", comment: ""), UIImage(named: "MenuFile")!),
        ]
            
        view.addSubview(shareMoreView)
        shareMoreView.snp.makeConstraints { (make) -> Void in
            make.left.right.equalToSuperview()
            make.top.equalTo(self.chatActionBarView.snp.bottom).offset(0)
            make.height.equalTo(kCustomKeyboardHeight + UIApplication.safeAreaInsets.bottom)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ConversationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIButton {
            return false
        }
        return true
    }
}

extension ConversationViewController: ChatShareMoreViewDelegate {
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
                                self.dataSource.addFileMessage(destinationPath)
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
                                self.dataSource.addFileMessage(tempDestinationPath)
                            }
                        } catch {
                            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
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
        cameraViewController.didSendImage = { [weak self] image in
            self?.dataSource.addPhotoMessage(image)
            self?.dismiss(animated: true, completion: nil)
        }
        cameraViewController.didSendFile = { [weak self] url in
            self?.dataSource.addFileMessage(url)
            self?.dismiss(animated: true, completion: nil)
        }
        present(cameraViewController, animated: true, completion: nil)
    }
    
    func chatShareMoreViewFileTaped() {
        let vc = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .import)
        vc.delegate = self
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true, completion: nil)
    }
    
    func chatShareMoreViewAudioCallTaped() {
        NotificationCenter.default.post(name: NSNotification.Name.StartVoiceCall, object: nil, userInfo: ["chat": self.dataSource.chat])
    }
}

extension ConversationViewController: ChatEmotionInputViewDelegate {
    func chatEmoticonInputViewDidTapCell(_ cell: ChatEmotionCell) {
        
    }
    
    func chatEmoticonInputViewDidTapBackspace(_ cell: ChatEmotionCell) {
        
    }
    
    func chatEmoticonInputViewDidTapSend() {
        
    }
}

extension ConversationViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            dataSource.addTextMessage(textView.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
            textView.text = ""
            controlExpandableInputView(showExpandable: true, animation: true, scrollToBottom: false)
            dataSource.audioPlayer.playSound(.sent)
            return false
        }
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        controlExpandableInputView(showExpandable: true)
    }
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        chatActionBarView.inputTextViewCallKeyboard()
        
        controlExpandableInputView(showExpandable: true)
        
        UIView.setAnimationsEnabled(false)
        let range = NSMakeRange(textView.text.count - 1, 1)
        textView.scrollRangeToVisible(range)
        UIView.setAnimationsEnabled(true)
        return true
    }
}

public enum CellVerticalEdge {
    case top
    case bottom
}

extension CGFloat {
    static let bma_epsilon: CGFloat = 10
}

extension UICollectionView {
    
    public func isScrolledAtBottom() -> Bool {
        let collectionView = self
        guard collectionView.numberOfSections > 0 && collectionView.numberOfItems(inSection: 0) > 0 else { return true }
        let sectionIndex = collectionView.numberOfSections - 1
        let itemIndex = collectionView.numberOfItems(inSection: sectionIndex) - 1
        let lastIndexPath = IndexPath(item: itemIndex, section: sectionIndex)
        return self.isIndexPathVisible(lastIndexPath, atEdge: .bottom)
    }
    
    public func isScrolledAtTop() -> Bool {
        let collectionView = self
        guard collectionView.numberOfSections > 0 && collectionView.numberOfItems(inSection: 0) > 0 else { return true }
        let firstIndexPath = IndexPath(item: 0, section: 0)
        return self.isIndexPathVisible(firstIndexPath, atEdge: .top)
    }
    
    public func isIndexPathVisible(_ indexPath: IndexPath, atEdge edge: CellVerticalEdge) -> Bool {
        let collectionView = self
        guard let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else { return false }
        let visibleRect = self.visibleRect()
        let intersection = visibleRect.intersection(attributes.frame)
        if edge == .top {
            return abs(intersection.minY - attributes.frame.minY) < CGFloat.bma_epsilon
        } else {
            return abs(intersection.maxY - attributes.frame.maxY) < CGFloat.bma_epsilon
        }
    }
    
    public func visibleRect() -> CGRect {
        let collectionView = self
        let contentInset = collectionView.contentInset
        let collectionViewBounds = collectionView.bounds
        let contentSize = collectionView.collectionViewLayout.collectionViewContentSize
        return CGRect(x: CGFloat(0), y: collectionView.contentOffset.y + contentInset.top, width: collectionViewBounds.width, height: min(contentSize.height, collectionViewBounds.height - contentInset.top - contentInset.bottom))
    }
    
    @objc
    open func scrollToBottom(_ animated: Bool) {
        let collectionView = self
        // Cancel current scrolling
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)

        // Note that we don't rely on collectionView's contentSize. This is because it won't be valid after performBatchUpdates or reloadData
        // After reload data, collectionViewLayout.collectionViewContentSize won't be even valid, so you may want to refresh the layout manually
        let offsetY = max(-collectionView.contentInset.top, collectionView.collectionViewLayout.collectionViewContentSize.height - collectionView.bounds.height + collectionView.contentInset.bottom)

        // Don't use setContentOffset(:animated). If animated, contentOffset property will be updated along with the animation for each frame update
        // If a message is inserted while scrolling is happening (as in very fast typing), we want to take the "final" content offset (not the "real time" one) to check if we should scroll to bottom again
        if animated {
            UIView.animate(withDuration: 0.33, animations: { () -> Void in
                collectionView.contentOffset = CGPoint(x: 0, y: offsetY)
            })
        } else {
            collectionView.contentOffset = CGPoint(x: 0, y: offsetY)
        }
    }
    
    public func scrollToPreservePosition(oldRefRect: CGRect?, newRefRect: CGRect?) {
        let collectionView = self
        guard let oldRefRect = oldRefRect, let newRefRect = newRefRect else {
            return
        }
        let diffY = newRefRect.minY - oldRefRect.minY
        collectionView.contentOffset = CGPoint(x: 0, y: collectionView.contentOffset.y + diffY)
    }
}
