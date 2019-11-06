//
//  StringExtension.swift
//  Tok
//
//  Created by Bryce on 2018/6/24.
//  Copyright © 2018 Insight. All rights reserved.
//

import Foundation

extension String {
    /**
     true if self contains characters.
     */
    var isNotEmpty: Bool {
        return !isEmpty
    }
    
    func substring(endChar: Character) -> String {
        guard let endIndex = self.firstIndex(of: endChar) else {
            return self
        }
        return String(self[..<endIndex])
    }
}

let tokIdRegex = try! NSRegularExpression(pattern: "[A-Za-z0-9]{\(kOCTToxAddressLength)}", options: [])
let groupShareIdRegex = try! NSRegularExpression(pattern: "#[A-Za-z0-9]{19}", options: [])

extension String {
//    func isAddressString() -> Bool {
//        let nsstring = self.trimmingCharacters(in: .whitespacesAndNewlines)
//
//        if nsstring.count != Int(kOCTToxAddressLength) {
//            return false
//        }
//
//        let validChars = CharacterSet(charactersIn: "1234567890abcdefABCDEF")
//        let components = (nsstring as NSString).components(separatedBy: validChars)
//        let leftChars = components.joined(separator: "")
//
//        return leftChars.isEmpty
//    }
    
    func matchAddressString() -> String? {
        let len = kOCTToxAddressLength
        let pattern = "[A-Za-z0-9]{\(len)}"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count))
            
            if let range = match?.range(at: 0) {
                let command = (self as NSString).substring(with: range)
                let address = String(command)
                return address.uppercased()
            }
        } catch {
            return nil
        }
        return nil
    }
    
    func matchCommandString() -> String? {
        let len = kOCTToxAddressLength
        let pattern = "\\$[A-Za-z0-9]{\(len)}\\$"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count))
            
            if let range = match?.range(at: 0) {
                let command = (self as NSString).substring(with: range)
                let address = String(command.dropFirst().dropLast())
                return address.uppercased()
            }
        } catch {
            return nil
        }
        return nil
    }
    
    func matchGroupShareIdString() -> String? {
        let regex = groupShareIdRegex
        let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count))
        
        if let range = match?.range(at: 0) {
            let shareId = (self as NSString).substring(with: range)
            return shareId
        }
        return nil
    }
    
    func matchGroupNumber() -> Int? {
        guard let groupShareId = self.matchGroupShareIdString() else {
            return nil
        }
        guard let idLength = Int(groupShareId[18..<19]),
            let groupNumber = Int(groupShareId[(18-idLength)..<18]) else {
                return nil
        }
        
        return groupNumber
    }
}

extension String {
    func isEnglishLetters() -> Bool {
        let regex = "^[A-Za-z]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }
}

extension String {
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    init(timeInterval: TimeInterval) {
        var timeInterval = timeInterval
        
        let hours = Int(timeInterval / 3600)
        timeInterval -= TimeInterval(hours * 3600)
        
        let minutes = Int(timeInterval / 60)
        timeInterval -= TimeInterval(minutes * 60)
        
        let seconds = Int(timeInterval)
        
        if hours > 0 {
            self.init(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        else {
            self.init(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func substringToByteLength(_ length: Int, encoding: String.Encoding) -> String {
        guard length > 0 else {
            return ""
        }
        
        var substring = self as NSString
        
        while substring.lengthOfBytes(using: encoding.rawValue) > length {
            let newLength = substring.length - 1
            
            guard newLength > 0 else {
                return ""
            }
            
            substring = substring.substring(to: newLength) as NSString
        }
        
        return substring as String
    }
    
    func stringSizeWithFont(_ font: UIFont) -> CGSize {
        return stringSizeWithFont(font, constrainedToSize:CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
    }
    
    func stringSizeWithFont(_ font: UIFont, constrainedToSize size: CGSize) -> CGSize {
        let boundingRect = (self as NSString).boundingRect(
            with: size,
            options: .usesLineFragmentOrigin,
            attributes: [NSAttributedString.Key.font : font],
            context: nil)
        
        return CGSize(width: ceil(boundingRect.size.width), height: ceil(boundingRect.size.height))
    }
}

extension String {
    subscript(_ range: CountableRange<Int>) -> String {
        let idx1 = index(startIndex, offsetBy: max(0, range.lowerBound))
        let idx2 = index(startIndex, offsetBy: min(self.count, range.upperBound))
        return String(self[idx1..<idx2])
    }
    
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()

        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
}

extension String {
    func validateIpOrHost() -> Bool {
        return validateIpAddress() || validateHost()
    }
    
    func validateIpAddress() -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        if self.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return true
        }
        else if self.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
            // IPv4 peer.
            return true
        }

        return false
    }
    
    func validateHost() -> Bool {
        let regex = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }
    
    func validatePort() -> Bool {
        let regex = "^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]{1}|6553[0-5])$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }
}
