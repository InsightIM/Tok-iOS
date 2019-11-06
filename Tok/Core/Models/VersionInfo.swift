//
//  VersionInfo.swift
//  Tok
//
//  Created by Bryce on 2019/10/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

struct VersionInfo {
    struct AppleAccount {
        let email: String
        let password: String
    }
    
    let versionCode: UInt32
    let version: String?
    let updateDesc: String?
    let officialWebsite: [String]
    let accounts: [AppleAccount]
    
    init(pb: VersionInfoRes) {
        versionCode = pb.versionCode
        version = String(data: pb.version, encoding: .utf8)
        updateDesc = String(data: pb.updateDesc, encoding: .utf8)

        officialWebsite = {
            guard let websites = String(data: pb.officialWebsite, encoding: .utf8) else {
                return []
            }
            return websites.components(separatedBy: ";").filter { $0.isNotEmpty }
        }()
        
        accounts = {
            guard let remark = String(data: pb.remark, encoding: .utf8) else {
                return []
            }
            return remark.components(separatedBy: ";")
                .compactMap { str -> AppleAccount? in
                    let infos = str.components(separatedBy: ",")
                    guard let email = infos.first, let pwd = infos.last,
                        email.isNotEmpty, pwd.isNotEmpty else {
                        return nil
                    }
                    return AppleAccount(email: email, password: pwd)
            }
        }()
    }
}
