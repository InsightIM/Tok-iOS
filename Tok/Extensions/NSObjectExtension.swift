//
//  NSObjectExtension.swift
//  Tok
//
//  Created by Bryce on 2019/1/14.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Foundation

extension NSObject {
    /// The class's name
    class var ts_className: String {
        return NSStringFromClass(self).components(separatedBy: ".").last! as String
    }
    
    /// The class's identifier, for UITableView，UICollectionView register its cell
    class var ts_identifier: String {
        return String(format: "%@_identifier", self.ts_className)
    }
}
