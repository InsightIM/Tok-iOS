//
//  ConversionViewController+InputBar.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

extension ConversationViewController {
    
    func setupActionBarButtonInterAction() {
        let voiceButton: ChatButton = self.chatActionBarView.voiceButton
//        let recordButton: UIButton = self.chatActionBarView.recordButton
        let emotionButton: ChatButton = self.chatActionBarView.emotionButton
        let shareButton: ChatButton = self.chatActionBarView.shareButton
        
        voiceButton.rx.tap
            .subscribe {[weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.chatActionBarView.resetButtonUI()
                
                let showRecoring = strongSelf.chatActionBarView.recordButton.isHidden
                if showRecoring {
                    strongSelf.chatActionBarView.showRecording()
                    voiceButton.emotionSwiftVoiceButtonUI(showKeyboard: true)
                    strongSelf.controlExpandableInputView(showExpandable: false)
                } else {
                    strongSelf.chatActionBarView.showTyingKeyboard()
                    voiceButton.emotionSwiftVoiceButtonUI(showKeyboard: false)
                    strongSelf.controlExpandableInputView(showExpandable: true)
                }
            }
            .disposed(by: disposeBag)
        
        emotionButton.rx.tap
            .subscribe { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.chatActionBarView.resetButtonUI()
                
                emotionButton.replaceEmotionButtonUI(showKeyboard: !emotionButton.showTypingKeyboard)
                
                if emotionButton.showTypingKeyboard {
                    strongSelf.chatActionBarView.showTyingKeyboard()
                } else {
                    strongSelf.chatActionBarView.showEmotionKeyboard()
                }
                
                strongSelf.controlExpandableInputView(showExpandable: true)
            }
            .disposed(by: self.disposeBag)
        
        shareButton.rx.tap
            .subscribe { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.chatActionBarView.resetButtonUI()
                
                if shareButton.showTypingKeyboard {
                    strongSelf.chatActionBarView.showTyingKeyboard()
                } else {
                    strongSelf.chatActionBarView.showShareKeyboard()
                }
                
                strongSelf.controlExpandableInputView(showExpandable: true)
            }
            .disposed(by: self.disposeBag)
    }
    
    /**
     Control the actionBarView height:
     We should make actionBarView's height to original value when the user wants to show recording keyboard.
     Otherwise we should make actionBarView's height to currentHeight
     
     - parameter showExpandable: show or hide expandable inputTextView
     - parameter forceUpdate: force update inputview height when keyboard show or hide
     - parameter animation: Bool
     - parameter scrollToBottom: Bool
     */
    func controlExpandableInputView(showExpandable: Bool, forceUpdate: Bool = false, animation: Bool = true, scrollToBottom: Bool = true, forceHideKeyboard: Bool = false) {
        let animationDuration = 0.25
        let updateBlock = {
            self.view.layoutIfNeeded()
            if scrollToBottom {
                self.messagesCollectionView.scrollToBottomAnimated(false)
            }
        }
        
        if showExpandable == false {
            self.chatActionBarView.snp.updateConstraints { (make) -> Void in
                make.height.equalTo(kChatActionBarOriginalHeight)
            }
            
            if animation {
                UIView.animate(withDuration: animationDuration, animations: updateBlock)
            } else {
                updateBlock()
            }
        } else {
            if updateTextViewHeight(forceHideKeyboard: forceHideKeyboard, forceUpdate: forceUpdate) {
                if animation {
                    UIView.animate(withDuration: animationDuration, animations: updateBlock)
                } else {
                    updateBlock()
                }
            }
        }
    }
    
    @discardableResult
    func updateTextViewHeight(forceHideKeyboard: Bool, forceUpdate: Bool) -> Bool {
        guard let textView = self.chatActionBarView.inputTextView,
            let lineHeight = textView.font?.lineHeight else {
                return false
        }
        
        let padding: CGFloat = 10
        let textViewWidth = UIScreen.main.bounds.width - padding * 3 - 6 * 1 - 35 * 2
        
        let maxHeight = ceil(lineHeight * CGFloat(kChatActionBarMaxRows) + textView.textContainerInset.top + textView.textContainerInset.bottom)
        let contentSize = textView.sizeThatFits(CGSize(width: textViewWidth, height: UIView.layoutFittingExpandedSize.height))
        
        textView.isScrollEnabled = contentSize.height > maxHeight
        
        let newHeight = min(contentSize.height, maxHeight)
        let heightDifference = newHeight - textView.height
        
        if abs(heightDifference) > 0.1 || forceUpdate {
            let keyboardIsShowing = forceHideKeyboard
                ? false
                : (actionBarPaddingBottomConstranit?.layoutConstraints[0].constant ?? 0) < 0.0
            
            let height = keyboardIsShowing ? newHeight + 12 * 2 : max(kChatActionBarOriginalHeight, kChatActionBarOriginalHeight + newHeight - 36)
            self.chatActionBarView.snp.updateConstraints { (make) -> Void in
                make.height.equalTo(height)
                if forceHideKeyboard {
                    make.bottom.equalToSuperview()
                }
            }
            
            return true
        }
        
        return false
    }
}
