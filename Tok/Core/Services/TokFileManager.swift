//
//  TokFileManager.swift
//  Tok
//
//  Created by Bryce on 2019/7/26.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class TokFileManager {
    enum ChatDirectory: String {
        case files = "files"
        case thumbs = "thumbs"
        case avatars = "avatars"
        case temps = "temps"
    }
    
    struct Constants {
        static let tokExtension = "tok"
        static let databaseName = "database"
        static let encryptionkeyName = "database.encryptionkey"
        static let downloadFolder = "files"
    }
    
    let fileName: String
    init(fileName: String) {
        self.fileName = fileName
    }
    
    var rootDirectory: URL {
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Tok").appendingPathComponent(fileName)
        _ = FileManager.default.createNobackupDirectory(dir)
        return dir
    }
    
    var tokFilePath: URL {
        guard let fullName = (fileName as NSString).appendingPathExtension(Constants.tokExtension) else {
            fatalError()
        }
        return rootDirectory.appendingPathComponent(fullName)
    }
    
    var databasePath: URL {
        return rootDirectory.appendingPathComponent(Constants.databaseName)
    }
    
    var databaseEncryptionKeyPath: URL {
        return rootDirectory.appendingPathComponent(Constants.encryptionkeyName)
    }
    
    func url(atChatDirectory directory: ChatDirectory, fileName: String?) -> URL {
       let url = rootDirectory.appendingPathComponent(directory.rawValue)
        TokFileManager.createDirectoryIfNeeded(path: url.path)
        if let fileName = fileName {
            return url.appendingPathComponent(fileName)
        } else {
            return url
        }
    }
    
    func tempPath(fileName: String = UUID().uuidString, pathExtension: String) -> URL {
        let folder = (NSTemporaryDirectory() as NSString).appendingPathComponent("files")
        TokFileManager.createDirectoryIfNeeded(path: folder)
        let path = URL(fileURLWithPath: folder).appendingPathComponent(fileName).appendingPathExtension(pathExtension)
        return path
    }
    
    static func createDirectoryIfNeeded(path: String) {
        let fileManager = FileManager.default
        var isDirectory = ObjCBool(false)
        var exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        if exists, !isDirectory.boolValue {
            try? fileManager.removeItem(atPath: path)
            exists = false
        }
        
        if !exists {
            try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

private extension FileManager {
    func createDirectoryIfNeeded(dir: URL) throws {
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func createNobackupDirectory(_ directory: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: directory.path) else {
            return true
        }
        do {
            var dir = directory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try dir.setResourceValues(values)
            return true
        } catch let error {
            print("======FileManagerExtension...error:\(error)")
            return false
        }
    }
}
