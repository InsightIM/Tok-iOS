//
//  ProxyModel.swift
//  Tok
//
//  Created by Bryce on 2019/9/30.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

struct ProxyModel: Codable, Equatable {
    let server: String
    let port: UInt
    let username: String?
    let password: String?
    let selected: Bool
    
    func change(selected: Bool) -> ProxyModel {
        return ProxyModel(server: server, port: port, username: username, password: password, selected: selected)
    }
    
    enum CodingKeys : String, CodingKey {
        case server
        case port
        case username
        case password
        case selected
    }
    
    static func ==(lhs: ProxyModel, rhs: ProxyModel) -> Bool {
        return lhs.server == rhs.server && lhs.port == rhs.port
    }
    
    struct Constants {
        static let fileName = "proxy.json"
    }
    
    static func retrieve() -> [ProxyModel] {
        guard Storage.fileExists(Constants.fileName, in: .library) else {
            return []
        }
        return Storage.retrieve(Constants.fileName, from: .library, as: [ProxyModel].self)
    }
    
    static func store(models: [ProxyModel]) {
        Storage.store(models, to: .library, as: Constants.fileName)
    }
    
    static func add(model: ProxyModel) {
        var allModels = ProxyModel.retrieve().filter { $0 != model }.map { $0.change(selected: false) }
        allModels.insert(model, at: 0)
        ProxyModel.store(models: allModels)
    }
}
