//
//  FilePathOutput.swift
//  Tok
//
//  Created by Bryce on 2019/8/2.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class FilePathOutput: FileOutputProtocol {
    private var handle: FileHandle?
    
    let tempFilePath: URL
    let resultFilePath: URL
    
    init(tempFilePath: URL, resultFilePath: URL) {
        self.tempFilePath = tempFilePath
        self.resultFilePath = resultFilePath
        // Create dummy file to reserve fileName.
//        FileManager.default.createFile(atPath: resultFilePath.path, contents: Data(), attributes: nil)
    }
    
    func prepareToWrite() -> Bool {
        guard FileManager.default.createFile(atPath: tempFilePath.path, contents: nil, attributes: nil) else {
            return false
        }
        handle = try? FileHandle(forWritingTo: tempFilePath)
        return handle != nil
    }
    
    func write(data: Data) -> Bool {
        guard let handle = self.handle else {
            return false
        }
        handle.write(data)
        return true
    }
    
    func finishWriting() -> Bool {
        guard let handle = self.handle else {
            return false
        }
        
        handle.synchronizeFile()
        
        print("finishWriting: tempFilePath:\(tempFilePath) , resultFilePath:\(resultFilePath)")
        do {
            // Remove dummy file.
//            try FileManager.default.removeItem(at: resultFilePath)
            // Move file
            try FileManager.default.moveItem(at: tempFilePath, to: resultFilePath)
            return true
        } catch {
            print("finishWriting: \(error)")
            return false
        }
    }
    
    func cancel() {
        handle = nil
        try? FileManager.default.removeItem(at: resultFilePath)
    }
}
