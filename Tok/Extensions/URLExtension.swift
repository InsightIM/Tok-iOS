//
//  URLExtension.swift
//  Tok
//
//  Created by Bryce on 2018/7/22.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

import Foundation
import MobileCoreServices

extension URL {
    func isToxURL() -> Bool {
        guard isFileURL else {
            return false
        }
        
        return ["tox", "tok"].contains(pathExtension.lowercased())
    }
}
