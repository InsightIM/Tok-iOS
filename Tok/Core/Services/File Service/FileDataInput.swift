//
//  FileDataInput.swift
//  Tok
//
//  Created by Bryce on 2019/8/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class FileDataInput: FileInputProtocol {
    
    private let data: Data
    init(data: Data) {
        self.data = data
    }
    
    func prepareToRead() -> Bool {
        return true
    }
    
    func bytesWithPosition(position: OCTToxFileSize, length: UInt) -> Data? {
        guard let range = Range(NSRange(location: Int(position), length: Int(length))) else {
            return nil
        }
        return data.subdata(in: range)
    }
}
