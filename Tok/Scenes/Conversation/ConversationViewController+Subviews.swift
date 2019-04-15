//
//  ConversationViewController+Subviews.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import HXPhotoPicker

extension ConversationViewController {
    
    func setupSubviews(_ delegate: UITextViewDelegate) {
        setupActionBar(delegate)
        setupNavigateItem()
        setupCollectionView()
        setupKeyboardInputView()
    }
    
    fileprivate func setupNavigateItem() {
        let barButton = UIBarButtonItem(image: UIImage(named: "NavbarMore"), style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = barButton
        barButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.didClickAvatar(isOutgoing: false)
            })
            .disposed(by: disposeBag)
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
            if let photoList = photoList as NSArray? {
                photoList.hx_requestImage(withOriginal: isOriginal, completion: { (imageList, _) in
                    imageList?.forEach { image in
                        self.dataSource.addPhotoMessage(image, isOriginal: isOriginal)
                    }
                })
            }
            
            if let videoList = videoList as NSArray? {
                ProgressHUD.showLoadingHUD(in: self.view)
                videoList.hx_requestVideoURL(withPresetName: AVAssetExportPresetMediumQuality, completion: { (urls) in
                    urls?.forEach { (url) in
                        self.dataSource.addFileMessage(url)
                    }
                    ProgressHUD.hideLoadingHUD(in: self.view)
                })
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
