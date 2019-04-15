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
    
    init(connectionStatus: OCTToxConnectionStatus, userStatus: OCTToxUserStatus) {
        switch (connectionStatus, userStatus) {
        case (.none, _):
            self = .offline
        case (_, .none):
            self = .online
        case (_, .away):
            self = .away
        case (_, .busy):
            self = .busy
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
