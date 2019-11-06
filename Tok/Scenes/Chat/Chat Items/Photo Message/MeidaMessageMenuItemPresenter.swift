//
//  MeidaMessageMenuItemPresenter.swift
//  Tok
//
//  Created by Bryce on 2019/7/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class MeidaMessageMenuItemPresenter: MessageMenuItemPresenter {
    override func canPerformMenuControllerAction(_ action: Selector) -> Bool {
        return action == .forward || action == .delete
    }
}

class AudioMessageMenuItemPresenter: MessageMenuItemPresenter {
    override func canPerformMenuControllerAction(_ action: Selector) -> Bool {
        return action == .delete
    }
}

class CallMessageMenuItemPresenter: MessageMenuItemPresenter {
    override func canPerformMenuControllerAction(_ action: Selector) -> Bool {
        return action == .delete
    }
}
