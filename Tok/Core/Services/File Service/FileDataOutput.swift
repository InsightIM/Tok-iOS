//
//  FileDataOutput.swift
//  Tok
//
//  Created by Bryce on 2019/8/8.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class FileDataOutput: FileOutputProtocol {
    private(set) var resultData: Data?
    
    func prepareToWrite() -> Bool {
        resultData = Data()
        return true
    }
    
    func write(data: Data) -> Bool {
        resultData?.append(data)
        return true
    }
    
    func finishWriting() -> Bool {
        return resultData != nil
    }
    
    func cancel() {
        resultData = nil
    }
    
    
}
