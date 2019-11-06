//
//  MessagesSelector.swift
//  Tok
//
//  Created by Bryce on 2019/5/18.
//  Copyright © 2019 Insight. All rights reserved.
//

import ChattoAdditions

protocol MessagesSelectorDelegate: class {
    func messagesSelector(_ messagesSelector: MessagesSelector, didSelectMessage: MessageModelProtocol)
    func messagesSelector(_ messagesSelector: MessagesSelector, didDeselectMessage: MessageModelProtocol)
}

class MessagesSelector {
    public weak var delegate: MessagesSelectorDelegate?
    
    public var isActive = false {
        didSet {
            guard oldValue != self.isActive else { return }
            if self.isActive {
                self.selectedMessagesDictionary.removeAll()
            }
        }
    }
    
    public func canSelectMessage(_ message: MessageModelProtocol) -> Bool {
        return true
    }
    
    public func isMessageSelected(_ message: MessageModelProtocol) -> Bool {
        return self.selectedMessagesDictionary[message.uid] != nil
    }
    
    public func selectMessage(_ message: MessageModelProtocol) {
        self.selectedMessagesDictionary[message.uid] = message
        self.delegate?.messagesSelector(self, didSelectMessage: message)
    }
    
    public func deselectMessage(_ message: MessageModelProtocol) {
        self.selectedMessagesDictionary[message.uid] = nil
        self.delegate?.messagesSelector(self, didDeselectMessage: message)
    }
    
    public func selectedMessages() -> [MessageModelProtocol] {
        return Array(self.selectedMessagesDictionary.values)
    }
    
    // MARK: - Private
    
    private var selectedMessagesDictionary = [String: MessageModelProtocol]()
}
