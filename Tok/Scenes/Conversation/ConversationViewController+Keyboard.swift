//
//  ConversationViewController+Keyboard.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

extension ConversationViewController {

    func keyboardControl() {
        /**
         Keyboard notifications
         */
        NotificationCenter.default
            .rx.notification(UIApplication.keyboardWillShowNotification, object: nil)
            .subscribe(onNext: { [weak self] notification in
                guard let self = self else { return }
                let duration = notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
                let curve = notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey] as! UInt
                
                self.keyboardDuration = duration
                self.keyboardCurve = curve
                self.messagesCollectionView.scrollToBottom(animated: false)
                self.keyboardControl(notification, isShowing: true)
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default
            .rx.notification(UIApplication.keyboardDidShowNotification, object: nil)
            .subscribe(onNext: {notification in
                if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                    _ = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
                }
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default
            .rx.notification(UIApplication.keyboardWillHideNotification, object: nil)
            .subscribe(onNext: { [weak self] notification in
                guard let self = self else { return }
                self.keyboardControl(notification, isShowing: false)
            })
            .disposed(by: disposeBag)
    }
    
    /**
     Handle keyboard Event
     http://stackoverflow.com/questions/19311045/uiscrollview-animation-of-height-and-contentoffset-jumps-content-from-bottom
     - parameter notification: NSNotification object
     - parameter isShowing: show or hide keyboard
     */
    func keyboardControl(_ notification: Notification, isShowing: Bool) {
        let keyboardType = self.chatActionBarView.keyboardType
        if keyboardType == .emotion || keyboardType == .share {
            return
        }
        
        if willMove {
            return
        }
        
        var userInfo = notification.userInfo!
        let keyboardRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue
        let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]! as AnyObject).uint32Value
        
        let convertedFrame = self.view.convert(keyboardRect!, from: nil)
        let heightOffset = self.view.bounds.size.height - convertedFrame.origin.y
        let options = UIView.AnimationOptions(rawValue: UInt(curve!) << 16 | UIView.AnimationOptions.beginFromCurrentState.rawValue)
        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue
        
        self.messagesCollectionView.stopScrolling()
        self.actionBarPaddingBottomConstranit?.update(offset:-heightOffset)
        
        controlExpandableInputView(showExpandable: true, forceUpdate: true, animation: false, scrollToBottom: false)
        
        UIView.animate(
            withDuration: duration!,
            delay: 0,
            options: options,
            animations: {
                self.view.layoutIfNeeded()
                if isShowing {
                    self.messagesCollectionView.scrollToBottomAnimated(false)
                }
        },
            completion: { bool in
                
        })
    }
    
    func appropriateKeyboardHeight(_ notification: Notification) -> CGFloat {
        let endFrame = (notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        var keyboardHeight: CGFloat = 0.0
        if notification.name == UIApplication.keyboardWillShowNotification {
            keyboardHeight = min(endFrame.width, endFrame.height)
        }
        
        if notification.name == Notification.Name("") {
            keyboardHeight = UIScreen.main.bounds.height - endFrame.origin.y
            keyboardHeight -= self.tabBarController!.tabBar.frame.height
        }
        return keyboardHeight
    }
    
    func appropriateKeyboardHeight()-> CGFloat {
        var height = self.view.bounds.size.height
        height -= self.keyboardHeightConstraint!.constant
        
        guard height > 0 else {
            return 0
        }
        return height
    }
    
    fileprivate func hideCusttomKeyboard() {
        messagesCollectionView.stopScrolling()
        controlExpandableInputView(showExpandable: true, forceUpdate: true, scrollToBottom: false, forceHideKeyboard: true)
    }
    
    func hideAllKeyboard() {
        self.hideCusttomKeyboard()
        self.chatActionBarView.resignKeyboard()
    }
}

// MARK: - @delegate ChatActionBarViewDelegate
extension ConversationViewController: ChatActionBarViewDelegate {
    
    func chatActionBarRecordVoiceHideKeyboard() {
        self.hideCusttomKeyboard()
    }
    
    func chatActionBarShowEmotionKeyboard() {
        let heightOffset = self.emotionInputView.height
        self.messagesCollectionView.stopScrolling()
        self.actionBarPaddingBottomConstranit?.update(offset: -heightOffset)
        
        self.emotionInputView.top = self.view.height
        UIView.animate(
            withDuration: keyboardDuration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: keyboardCurve),
            animations: {
                self.emotionInputView.snp.updateConstraints { make in
                    make.top.equalTo(self.chatActionBarView.snp.bottom).offset(0)
                }
                self.shareMoreView.snp.updateConstraints { make in
                    make.top.equalTo(self.chatActionBarView.snp.bottom).offset(self.view.height)
                }
                self.view.layoutIfNeeded()
                self.messagesCollectionView.scrollToBottomAnimated(false)
        },
            completion: { bool in
        })
    }
    
    func chatActionBarShowShareKeyboard() {
        let heightOffset = self.shareMoreView.height
        self.messagesCollectionView.stopScrolling()
        self.actionBarPaddingBottomConstranit?.update(offset: -heightOffset)
        
        self.shareMoreView.top = self.view.height
        self.view.bringSubviewToFront(self.shareMoreView)
        UIView.animate(
            withDuration: keyboardDuration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: keyboardCurve),
            animations: {
                self.emotionInputView.snp.updateConstraints { make in
                    make.top.equalTo(self.chatActionBarView.snp.bottom).offset(self.view.height)
                }
                self.shareMoreView.snp.updateConstraints { make in
                    make.top.equalTo(self.chatActionBarView.snp.bottom).offset(0)
                }
                self.view.layoutIfNeeded()
                self.messagesCollectionView.scrollToBottomAnimated(false)
        },
            completion: { bool in
        })
    }
}
