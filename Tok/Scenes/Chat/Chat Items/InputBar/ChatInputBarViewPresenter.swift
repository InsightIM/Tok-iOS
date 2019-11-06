//
//  ChatInputBarViewPresenter.swift
//  Tok
//
//  Created by Bryce on 2019/5/21.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

protocol ChatInputBarViewPresenter: class {
    var chatInputBar: ChatInputBar { get }
    func onDidBeginEditing()
    func onDidEndEditing(force: Bool)
    func onSendButtonPressed()
    func onDidReceiveFocusOnItem(_ item: ChatInputItemProtocol)
}

class ExpandableChatInputBarPresenter: NSObject, ChatInputBarViewPresenter {
    let chatInputBar: ChatInputBar
    let chatInputItems: [ChatInputItemProtocol]
    let notificationCenter: NotificationCenter
    
    let animationDuration = 0.33 // CATransaction.animationDuration()
    weak var inputPositionController: InputPositionControlling?
    
    init(inputPositionController: InputPositionControlling,
         chatInputBar: ChatInputBar,
         notificationCenter: NotificationCenter = NotificationCenter.default) {
        self.inputPositionController = inputPositionController
        
        self.chatInputBar = chatInputBar
        self.chatInputItems = chatInputBar.chatInputItems
        self.notificationCenter = notificationCenter
        super.init()
        
        self.chatInputBar.presenter = self

        self.notificationCenter.addObserver(self, selector: #selector(keyboardDidChangeFrame), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(handleOrienationDidChangeNotification), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
    deinit {
        self.notificationCenter.removeObserver(self)
    }
    
    fileprivate(set) var focusedItem: ChatInputItemProtocol? {
        willSet {
            self.focusedItem?.selected = false
        }
        didSet {
            self.focusedItem?.selected = true
        }
    }
    
    fileprivate var shouldIgnoreContainerBottomMarginUpdates: Bool = false
    fileprivate func updateContentContainer(withInputItem inputItem: ChatInputItemProtocol) {
        self.cleanCurrentInputView()
        let responder = self.chatInputBar.textView!
        if inputItem.presentationMode == .keyboard {
            responder.becomeFirstResponder()
        } else if let inputView = inputItem.inputView, let inputPositionController = self.inputPositionController {
            responder.resignFirstResponder()
            self.setup(inputBar: inputView, bottomMargin: inputItem.expandedStateTopMargin, inContainerOfInputBarController: inputPositionController)
        }
    }
    
    private func cleanCurrentInputView(animated: Bool = false, completion: (() -> Void)? = nil) {
        self.currentInputView?.endEditing(false)
        if animated {
            UIView.animate(withDuration: animationDuration, animations: {
                self.currentInputView?.alpha = 0.0
            }, completion: { (_) in
                self.currentInputView?.removeFromSuperview()
                completion?()
            })
        } else {
            self.currentInputView?.removeFromSuperview()
            completion?()
        }
    }
    
    private func setup(inputBar: UIView, bottomMargin: CGFloat? = nil, inContainerOfInputBarController inputBarController: InputPositionControlling) {
        self.shouldIgnoreContainerBottomMarginUpdates = true
        inputBarController.changeInputContentBottomMarginTo(bottomMargin ?? self.keyboardHeight, animated: true, callback: {
            self.shouldIgnoreContainerBottomMarginUpdates = false
        })
        let containerView: InputContainerView = {
            let containerView = InputContainerView()
            containerView.allowsSelfSizing = true
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.contentView = inputBar
            return containerView
        }()
        inputBarController.inputContentContainer.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: inputBarController.inputContentContainer.topAnchor),
            containerView.leftAnchor.constraint(equalTo: inputBarController.inputContentContainer.leftAnchor),
            containerView.rightAnchor.constraint(equalTo: inputBarController.inputContentContainer.rightAnchor),
            containerView.bottomAnchor.constraint(equalTo: inputBarController.inputContentContainer.bottomAnchor)
            ])
        self.currentInputView = containerView
    }
    
    private var lastKnownKeyboardHeight: CGFloat?
    private var keyboardHeight: CGFloat {
        return self.lastKnownKeyboardHeight ?? self.defaultKeyboardHeight
    }
    private var allowListenToChangeFrameEvents = true
    
    // MARK: Input View
    
    private weak var currentInputView: InputContainerView?
    
    private var defaultKeyboardHeight: CGFloat {
        if UIApplication.shared.statusBarOrientation.isPortrait {
            return UIScreen.main.defaultPortraitKeyboardHeight
        } else {
            return UIScreen.main.defaultLandscapeKeyboardHeight
        }
    }
    
    private func expandedInputViewHeight(forItem item: ChatInputItemProtocol) -> CGFloat {
        return item.expandedStateTopMargin
    }
    
    // MARK: Notifications handling
    
    @objc
    private func keyboardDidChangeFrame(_ notification: Notification) {
        guard self.allowListenToChangeFrameEvents else { return }
        guard let value = (notification as NSNotification).userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        guard value.cgRectValue.height > 0 else { return }
        self.lastKnownKeyboardHeight = value.cgRectValue.height - self.chatInputBar.bounds.height
    }
    
    @objc
    private func keyboardWillHide(_ notification: Notification) {
        self.allowListenToChangeFrameEvents = false
    }
    
    @objc
    private func keyboardWillShow(_ notification: Notification) {
        self.allowListenToChangeFrameEvents = true
    }
    
    @objc
    private func handleOrienationDidChangeNotification(_ notification: Notification) {
        self.lastKnownKeyboardHeight = nil
        if let currentInputView = self.currentInputView {
            currentInputView.contentHeight = self.keyboardHeight
            self.inputPositionController?.changeInputContentBottomMarginTo(self.keyboardHeight, animated: true, callback: nil)
        }
    }
    
    // MARK: Controllers updates handling

    private func onKeyboardStateDidChange(bottomMargin: CGFloat, keyboardStatus: KeyboardStatus) {
        guard let inputPositionController = self.inputPositionController else { return }

        switch keyboardStatus {
        case .showing:
            self.focusedItem?.selected = false
            if self.focusedItem == nil || self.focusedItem?.presentationMode == .keyboard {
                inputPositionController.changeInputContentBottomMarginTo(bottomMargin, animated: true, callback: nil)
                if self.focusedItem != nil {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.currentInputView?.alpha = 0
                    }) { _ in
                        self.focusedItem = nil
                        self.currentInputView?.removeFromSuperview()
                    }
                }
            }
        case .hiding, .hidden:
            if let item = self.focusedItem {
                inputPositionController.changeInputContentBottomMarginTo(self.expandedInputViewHeight(forItem: item), animated: true, callback: nil)
            } else {
                inputPositionController.changeInputContentBottomMarginTo(bottomMargin, animated: true, callback: nil)
            }
        case .shown: break
        }
    }
    
    private func onScrollViewDidEndDragging(willDecelerate decelerate: Bool) {
        guard self.shouldProcessScrollViewUpdates() else { return }
        guard let inputPositionController = self.inputPositionController else { return }
        self.shouldIgnoreContainerBottomMarginUpdates = true
        if 3 * inputPositionController.inputContentBottomMargin < self.keyboardHeight {
            let callback: () -> Void = { [weak self] in
                self?.shouldIgnoreContainerBottomMarginUpdates = false
                if let self = self, let item = self.focusedItem, self.expandedInputViewHeight(forItem: item) > 0 {
                    self.cleanupFocusedItem(animated: true)
                }
            }
            inputPositionController.changeInputContentBottomMarginTo(0, animated: true, callback: callback)
        } else {
            let callback: () -> Void = { [weak self] in self?.shouldIgnoreContainerBottomMarginUpdates = false }
            if let item = self.focusedItem {
                let height = self.expandedInputViewHeight(forItem: item)
                inputPositionController.changeInputContentBottomMarginTo(height, animated: true, callback: callback)
            }
        }
    }
    
    private func onScrollViewDidScroll(velocity: CGPoint, location: CGPoint) {
        self.currentInputView?.endEditing(false)
        guard let inputPositionController = self.inputPositionController else { return }
        
        if location.y > 0 {
            inputPositionController.changeInputContentBottomMarginTo(inputPositionController.inputContentBottomMargin - location.y, animated: false, callback: nil)
        } else if inputPositionController.inputContentBottomMargin < self.keyboardHeight && velocity.y < 0 {
            if let item = focusedItem {
                inputPositionController.changeInputContentBottomMarginTo(min(self.expandedInputViewHeight(forItem: item), inputPositionController.inputContentBottomMargin - location.y), animated: false, callback: nil)
            } else if self.chatInputBar.textView.isFirstResponder {
                inputPositionController.changeInputContentBottomMarginTo(min(self.keyboardHeight, inputPositionController.inputContentBottomMargin - location.y), animated: false, callback: nil)
            }
        }
        
        if inputPositionController.inputContentBottomMargin == 0,
            let item = focusedItem, self.expandedInputViewHeight(forItem: item) > 0 {
            self.cleanupFocusedItem(animated: false)
        }
    }
    
    private func shouldProcessScrollViewUpdates() -> Bool {
        guard !self.shouldIgnoreContainerBottomMarginUpdates else { return false }
        return true
    }
    
    private func hideContentView(withVelocity velocity: CGPoint) {
        self.shouldIgnoreContainerBottomMarginUpdates = true
        let velocityAwareDuration = min(Double(self.keyboardHeight / velocity.y), animationDuration)
        self.inputPositionController?.changeInputContentBottomMarginTo(0, animated: true, duration: velocityAwareDuration, initialSpringVelocity: velocity.y, callback: { [weak self] in
            self?.shouldIgnoreContainerBottomMarginUpdates = false
            self?.cleanupFocusedItem(animated: true)
        })
    }
    
    private func cleanupFocusedItem(animated: Bool = false) {
        self.focusedItem = nil
        self.cleanCurrentInputView(animated: animated) {
            self.onDidEndEditing(force: false)
        }
    }
}

// MARK: ChatInputBarPresenter
extension ExpandableChatInputBarPresenter {
    public func onDidEndEditing(force: Bool) {
        if force {
            if self.focusedItem is AudioInputItem {
                return
            }
            
            inputPositionController?.changeInputContentBottomMarginTo(0, animated: true, callback: nil)
            self.focusedItem = nil
            self.chatInputBar.textView.inputView = nil
            cleanCurrentInputView(animated: false)
        } else {
            if self.focusedItem != nil {
                guard self.focusedItem?.presentationMode == .keyboard else { return }
            }
            self.focusedItem = nil
            self.chatInputBar.textView.inputView = nil
        }
    }
    
    public func onDidBeginEditing() {
//        if self.focusedItem == nil, let item = self.firstKeyboardInputItem() {
//            self.focusedItem = item
//            self.updateContentContainer(withInputItem: item)
//        }
    }
    
    func onSendButtonPressed() {
//        if let focusedItem = self.focusedItem {
//            focusedItem.handleInput(self.chatInputBar.inputText as AnyObject)
//        } else if let keyboardItem = self.firstKeyboardInputItem() {
//            keyboardItem.handleInput(self.chatInputBar.inputText as AnyObject)
//        }
        focusedItem?.handleInput(chatInputBar.textView.text as AnyObject)
        chatInputBar.textView.text = ""
    }
    
    func onDidReceiveFocusOnItem(_ item: ChatInputItemProtocol) {
        guard item.presentationMode != .none else { return }
        
        if item.presentationMode != .keyboard {
            self.focusedItem = item
            self.allowListenToChangeFrameEvents = false
        } else {
            self.focusedItem = nil
            self.allowListenToChangeFrameEvents = true
        }
        
        self.updateContentContainer(withInputItem: item)
    }
}

// MARK: KeyboardEventsHandling
extension ExpandableChatInputBarPresenter: KeyboardEventsHandling {
    
    public func onKeyboardStateDidChange(_ height: CGFloat, _ status: KeyboardStatus) {
        self.onKeyboardStateDidChange(bottomMargin: height, keyboardStatus: status)
    }
}

// MARK: ScrollViewEventsHandling
extension ExpandableChatInputBarPresenter: ScrollViewEventsHandling {
    
    public func onScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let inputPositionController = self.inputPositionController else { return }
        guard let view = scrollView.panGestureRecognizer.view else { return }
        let velocity = scrollView.panGestureRecognizer.velocity(in: view)
        let location = scrollView.panGestureRecognizer.location(in: inputPositionController.inputBarContainer)
        switch scrollView.panGestureRecognizer.state {
        case .changed:
            self.onScrollViewDidScroll(velocity: velocity, location: location)
        case .ended where velocity.y > 0:
            self.hideContentView(withVelocity: velocity)
        default:
            break
        }
    }
    
    public func onScrollViewDidEndDragging(_ scrollView: UIScrollView, _ decelerate: Bool) {
        self.onScrollViewDidEndDragging(willDecelerate: decelerate)
    }
}
