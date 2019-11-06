//
//  NodeModel.swift
//  Tok
//
//  Created by Bryce on 2019/9/30.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

struct NodeModel: Codable, Equatable {
    
    let server: String
    let port: UInt
    let publicKey: String
    let networkProtocol: NetworkProtocol
    
    enum NetworkProtocol: String, Codable {
        case TCP
        case UDP
    }
    
    enum CodingKeys : String, CodingKey {
        case server
        case port
        case publicKey
        case networkProtocol
    }
    
    static func ==(lhs: NodeModel, rhs: NodeModel) -> Bool {
        return lhs.server == rhs.server
            && lhs.port == rhs.port
            && lhs.publicKey == rhs.publicKey
            && lhs.networkProtocol == rhs.networkProtocol
    }
    
    struct Constants {
        static let fileName = "nodes.json"
    }
    
    static func retrieve() -> [NodeModel] {
        guard Storage.fileExists(Constants.fileName, in: .library) else {
            return []
        }
        return Storage.retrieve(Constants.fileName, from: .library, as: [NodeModel].self)
    }
    
    static func store(models: [NodeModel]) {
        Storage.store(models, to: .library, as: Constants.fileName)
    }
    
    static func add(model: NodeModel) {
        var allModels = NodeModel.retrieve().filter { $0 != model }
        allModels.append(model)
        NodeModel.store(models: allModels)
    }
}

struct ToxNodes: Codable {
    var nodes: [Node]
    
    struct Node: Codable {
        let ipv4: String
        let ipv6: String
        let port: UInt
        let publicKey: String
        let tcpPorts: [UInt]?
        
        enum CodingKeys : String, CodingKey {
            case ipv4
            case ipv6
            case port
            case publicKey = "public_key"
            case tcpPorts = "tcp_ports"
        }
        
        static func decode(jsonString: String) -> Node? {
            guard let data = jsonString.data(using: .utf8) else {
                return nil
            }
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(Node.self, from: data)
                return model
            } catch {
                return nil
            }
        }
    }
    
    struct Constants {
        static let fileName = "remoteNodes.json"
    }
    
    static func filePath() -> URL {
        return Storage.filePath(Constants.fileName, in: .library)
    }
    
    static func retrieve() -> ToxNodes {
        guard Storage.fileExists(Constants.fileName, in: .library) else {
            return ToxNodes(nodes: [])
        }
        return Storage.retrieve(Constants.fileName, from: .library, as: ToxNodes.self)
    }
    
    static func store(data: Data?) {
        guard let data = data else { return }
        let url = filePath()
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try? data.write(to: filePath())
    }
    
    static func store(jsonString: String) {
        let data = jsonString.data(using: .utf8)
        store(data: data)
    }
    
    static func store(nodes: [Node]) {
        let toxNodes = ToxNodes(nodes: nodes)
        Storage.store(toxNodes, to: .library, as: Constants.fileName)
    }
    
    static func addNewNode(jsonString: String) {
        guard let node = ToxNodes.Node.decode(jsonString: jsonString) else { return }
        var root = ToxNodes.retrieve()
        root.nodes.insert(node, at: 0)
        Storage.store(root, to: .library, as: Constants.fileName)
    }
}
