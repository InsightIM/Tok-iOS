//
//  AudioItem.swift
//  Tok
//
//  Created by Bryce on 2019/3/13.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

public protocol AudioItem: FileItem {
    var duration: Int { get }
    var seconds: Int { get }
    var length: String { get }
    var contentWidth: CGFloat { get }
}
