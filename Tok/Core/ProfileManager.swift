//
//  ProfileManager.swift
//  Tok
//
//  Created by Bryce on 2018/6/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import Foundation

private struct Constants {
    static let SaveDirectoryPath = "Tok"
    
    // TODO get this constant from objcTox OCTDefaultFileStorage
    static let ToxFileName = "save.tox"
}

class ProfileManager {
    fileprivate(set) var allProfileNames: [String]
    
    init() {
        allProfileNames = []
        
        reloadProfileNames()
    }
    
    func createProfileWithName(_ name: String, copyFromURL: URL? = nil) throws {
        let path = pathFromName(name)
        let fileManager = FileManager.default
        
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        
        if let url = copyFromURL {
            let saveURL = URL(fileURLWithPath: path).appendingPathComponent(Constants.ToxFileName)
            try fileManager.moveItem(at: url, to: saveURL)
        }
        
        reloadProfileNames()
    }
    
    func deleteProfileWithName(_ name: String) throws {
        let path = pathFromName(name)
        
        try FileManager.default.removeItem(atPath: path)
        
        reloadProfileNames()
    }
    
    func renameProfileWithName(_ fromName: String, toName: String) throws {
        let fromPath = pathFromName(fromName)
        let toPath = pathFromName(toName)
        
        try FileManager.default.moveItem(atPath: fromPath, toPath: toPath)
        
        reloadProfileNames()
    }
    
    func pathForProfileWithName(_ name: String) -> String {
        return pathFromName(name)
    }
}

private extension ProfileManager {
    func saveDirectoryPath() -> String {
        let path: NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
        return path.appendingPathComponent(Constants.SaveDirectoryPath)
    }
    
    func pathFromName(_ name: String) -> String {
        let directoryPath: NSString = saveDirectoryPath() as NSString
        return directoryPath.appendingPathComponent(name)
    }
    
    func reloadProfileNames() {
        let fileManager = FileManager.default
        let savePath = saveDirectoryPath()
        
        let contents = try? fileManager.contentsOfDirectory(atPath: savePath)
        
        allProfileNames = contents?.filter {
            let path = (savePath as NSString).appendingPathComponent($0)
            
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: path, isDirectory:&isDirectory)
            
            return isDirectory.boolValue
            } ?? [String]()
    }
}
