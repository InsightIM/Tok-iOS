//
//  DataExtension.swift
//  Tok
//
//  Created by Bryce on 2018/10/2.
//  Copyright © 2018 Insight. All rights reserved.
//

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02.2hhX" : "%02.2hhx"
        return map { String(format: format, $0) }.joined()
    }
}
