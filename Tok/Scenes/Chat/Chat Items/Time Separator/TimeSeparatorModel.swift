//
//  TimeSeparatorModel.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Chatto

class TimeSeparatorModel: ChatItemProtocol {
    let uid: String
    let type: String = TimeSeparatorModel.chatItemType
    let date: String
    
    static var chatItemType: ChatItemType {
        return "TimeSeparatorModel"
    }
    
    init(uid: String, date: String) {
        self.uid = uid
        self.date = date
    }
}

class MessageDateFormatter {
    
    // MARK: - Properties
    
    public static let shared = MessageDateFormatter()
    
    private let formatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        return dateFormatter
    }()
    
    // MARK: - Initializer
    
    private init() {}
    
    // MARK: - Methods
    
    public func string(from date: Date) -> String {
        configureDateFormatter(for: date)
        return formatter.string(from: date)
    }
    
    public func attributedString(from date: Date, with attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let dateString = string(from: date)
        return NSAttributedString(string: dateString, attributes: attributes)
    }
    
    open func configureDateFormatter(for date: Date) {
        switch true {
        case Calendar.current.isDateInToday(date) || Calendar.current.isDateInYesterday(date):
            formatter.doesRelativeDateFormatting = true
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear):
            formatter.dateFormat = "EEEE h:mm a"
        case Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year):
            formatter.dateFormat = "EEEE, MMM dd, h:mm a"
        default:
            formatter.dateFormat = "MMM dd, yyyy, h:mm a"
        }
    }
    
}

extension Date {
    // Have a time stamp formatter to avoid keep creating new ones. This improves performance
    private static let weekdayAndDateStampDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateFormat = "EEEE, MMM dd yyyy" // "Monday, Mar 7 2016"
        return dateFormatter
    }()
    
    func toWeekDayAndDateString() -> String {
        return Date.weekdayAndDateStampDateFormatter.string(from: self)
    }
}
