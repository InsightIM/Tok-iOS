//
//  UserStatus.swift
//  Tok
//
//  Created by Bryce on 2018/6/24.
//  Copyright © 2018 Insight. All rights reserved.
//

import Foundation

enum UserStatus {
    case offline
    case online
    case away
    case busy
    
    init(connectionStatus: OCTToxConnectionStatus? = nil, userStatus: OCTToxUserStatus? = nil) {
        guard let connectionStatus = connectionStatus, let userStatus = userStatus else {
            self = .offline
            return
        }
        switch (connectionStatus, userStatus) {
        case (.none, _):
            self = .offline
        case (_, _):
            self = .online
        }
    }
    
    func toString() -> String {
        switch self {
        case .offline:
            return NSLocalizedString("Offline", comment: "")
        case .online:
            return NSLocalizedString("Online", comment: "")
        case .away:
            return NSLocalizedString("Away", comment: "")
        case .busy:
            return NSLocalizedString("Busy", comment: "")
        }
    }
}
