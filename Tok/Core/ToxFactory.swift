//
//  ToxFactory.swift
//  Tok
//
//  Created by Bryce on 2018/6/12.
//  Copyright © 2018 Insight. All rights reserved.
//

import Foundation

struct ToxFactory {
    static func createToxWithConfiguration(_ configuration: OCTManagerConfiguration,
                                           encryptPassword: String,
                                           successBlock: @escaping (OCTManager) -> Void,
                                           failureBlock: @escaping (Error) -> Void) {
//        if ProcessInfo.processInfo.arguments.contains("UI_TESTING") {
//            successBlock(OCTManagerMock())
//            return
//        }
        
        OCTManagerFactory.manager(with: configuration,
                                  encryptPassword: encryptPassword,
                                  successBlock: successBlock,
                                  failureBlock: failureBlock)
    }
}
