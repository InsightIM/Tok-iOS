//
//  DateFormatterExtension.swift
//  Tok
//
//  Created by Bryce on 2018/6/21.
//  Copyright © 2018 Insight. All rights reserved.
//

import Foundation

extension DateFormatter {
    enum FormatterType {
        case time
        case dateAndTime
        case relativeDate
        case relativeDateAndTime
    }
    
    convenience init(type: FormatterType) {
        self.init()
        
        switch type {
        case .time:
            dateFormat = "H:mm"
        case .dateAndTime:
            dateStyle = .short
            timeStyle = .short
            doesRelativeDateFormatting = false
        case .relativeDate:
            dateStyle = .short
            timeStyle = .none
            doesRelativeDateFormatting = true
        case .relativeDateAndTime:
            dateStyle = .short
            timeStyle = .short
            doesRelativeDateFormatting = true
        }
    }
}
