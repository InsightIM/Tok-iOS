//
//  FileItem.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

public protocol FileItem {
    var name: String { get }
    var fileSize: String { get }
    var path: String? { get }
}
