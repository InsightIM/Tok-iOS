//
//  BaseInuptItem.swift
//  Tok
//
//  Created by Bryce on 2019/5/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto
import ChattoAdditions

class BaseInuptItem: ChatInputItemProtocol {
    typealias Action = (ChatInputItemProtocol) -> Void
    
    private(set) var _presentationMode: ChatInputItemPresentationMode = .customView
    private(set) var _tabView: UIButton?
    private(set) var action: Action?
    
    init(tabView: UIButton, action: Action?) {
        self._tabView = tabView
        self.action = action
        
        self._tabView?.addTarget(self, action: #selector(didClick(sender:)), for: .touchUpInside)
    }
    
    @objc
    func didClick(sender: UIButton) {
        updateStatus(isSelected: !sender.isSelected)
        action?(self)
    }
    
    func updateStatus(isSelected: Bool) {
        _tabView?.isSelected = isSelected
        _presentationMode = isSelected ? .customView : .keyboard
    }
    
    var tabView: UIView {
        return _tabView!
    }
    
    var inputView: UIView? {
        return nil
    }
    
    var presentationMode: ChatInputItemPresentationMode {
        return _presentationMode
    }
    
    var showsSendButton: Bool {
        return false
    }
    
    var selected: Bool = false {
        didSet {
            updateStatus(isSelected: selected)
        }
    }
    
    var supportsExpandableState: Bool {
        return false
    }
    
    var expandedStateTopMargin: CGFloat {
        return 0
    }
    
    var shouldSaveDraftMessage: Bool {
        return false
    }
    
    func handleInput(_ input: AnyObject) {
        
    }
}

class MenuInputItem: BaseInuptItem {
    
    var isGroup: Bool = false
    
    weak var delegate: ChatMoreActionViewDelegate? {
        didSet {
            menuView.delegate = delegate
        }
    }
    
    override var inputView: UIView? {
        return menuView
    }
    
    override var supportsExpandableState: Bool {
        return true
    }
    
    override var expandedStateTopMargin: CGFloat {
        return 240
    }
    
    lazy var menuView: ChatMoreActionView = {
        let view = UIView.ts_viewFromNib(ChatMoreActionView.self)
        view.isGroup = self.isGroup
        return view
    }()
}

class AudioInputItem: BaseInuptItem {
    
    private(set) var changed: Action?
    
    init(tabView: UIButton, action: Action?, selectionChanged: Action?) {
        self.changed = selectionChanged
        super.init(tabView: tabView, action: action)
    }
    
    override func updateStatus(isSelected: Bool) {
        super.updateStatus(isSelected: isSelected)
        changed?(self)
    }
    
    override var inputView: UIView? {
        return UIView()
    }
    
    override var supportsExpandableState: Bool {
        return false
    }
    
    override var expandedStateTopMargin: CGFloat {
        return 0
    }
}
