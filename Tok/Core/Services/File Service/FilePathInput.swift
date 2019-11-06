//
//  FilePathInput.swift
//  Tok
//
//  Created by Bryce on 2019/8/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class FilePathInput: FileInputProtocol {
    private var handle: FileHandle?
    
    let filePath: String
    init(filePath: String) {
        self.filePath = filePath
    }
    
    func prepareToRead() -> Bool {
        handle = FileHandle(forReadingAtPath: filePath)
        return handle != nil
    }
    
    func bytesWithPosition(position: OCTToxFileSize, length: UInt) -> Data? {
        guard let handle = self.handle else {
            return nil
        }
        if handle.offsetInFile != position {
            handle.seek(toFileOffset: UInt64(position))
        }
        return handle.readData(ofLength: Int(length))
    }
}
