//
//  DynamicDomainService.swift
//  Tok
//
//  Created by Bryce on 2019/10/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

class DynamicDomainService {
    
    static let shared = DynamicDomainService()
    
    private let processQueue = DispatchQueue(label: "com.insight.dynamic.domain.process")
    
    private enum NetworkError: Error {
        case networkError
        case dataError
    }
    
    private struct Constants {
        static let nodesPath = "node.json"
        static let serverlistPath = "serverlist.json"
    }
    
    private lazy var domains: [String] = {
        let todayTimeInterval = Date().timeIntervalSince1970
        let yesterdayTimeInterval = todayTimeInterval - 24 * 60 * 60
        let tomorrowTimeInterval = todayTimeInterval + 24 * 60 * 60
        
        let today = OCTTox.dynamicDomain(with: todayTimeInterval)
        let yesterday = OCTTox.dynamicDomain(with: yesterdayTimeInterval)
        let tomorrow = OCTTox.dynamicDomain(with: tomorrowTimeInterval)
        
        return [today, yesterday, tomorrow].compactMap { $0 }
    }()
    
    // MARK: - Public
    
    func updateIfNeeded() {
        processQueue.async {
            guard self.checkLocalNodesAvaliable() == false else {
                return
            }
            self.update()
        }
    }
    
    // MARK: - Private
    
    private func update() {
        guard domains.isEmpty == false else { return }
        let domain = domains.removeFirst()
        guard let baseURL = URL(string: "https://" + domain) else { return }
        
        startDownload(url: baseURL.appendingPathComponent(Constants.nodesPath)) { [weak self] result in
            switch result {
            case .success(let model):
                self?.process(model)
            case .failure:
                self?.update()
            }
        }
    }
    
    private func startDownload(url: URL, completion: @escaping (Result<ToxNodes, NetworkError>) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, urlResponse, error in
            guard error == nil, let localURL = localURL, let data = try? Data(contentsOf: localURL) else {
                completion(.failure(.networkError))
                return
            }
            
            do {
                let model = try DynamicDomainService.parse(data: data)
                completion(.success(model))
            } catch {
                completion(.failure(.dataError))
            }
        }

        task.resume()
    }
    
    private static func parse(data: Data) throws -> ToxNodes {
        let decoder = JSONDecoder()
        let model = try decoder.decode(ToxNodes.self, from: data)
        return model
    }
    
    private func process(_ model: ToxNodes) {
        var nodes = ToxNodes.retrieve().nodes
        nodes.append(contentsOf: model.nodes)
        
        ToxNodes.store(nodes: nodes)
        UserService.shared.bootstrap()
    }
    
    private func checkUDP(_ node: ToxNodes.Node) -> Bool {
        let udpResult = OCTTox.checkBootstrapNode(node.ipv4, port: node.port, isTCP: false, publicKey: node.publicKey)
        return udpResult
    }
    
    private func checkTCP(_ node: ToxNodes.Node) -> Bool {
        guard let tcpPorts = node.tcpPorts else {
            return false
        }
        let results = tcpPorts.map { port -> Bool in
            OCTTox.checkBootstrapNode(node.ipv4, port: port, isTCP: true, publicKey: node.publicKey)
        }
        return results.contains(true)
    }
    
    private func checkLocalNodesAvaliable() -> Bool {
        let customerNodesAvaliable = UserDefaultsManager().customBootstrapEnabled
            ? NodeModel.retrieve().first {
                switch $0.networkProtocol {
                case .UDP:
                    return OCTTox.checkBootstrapNode($0.server, port: $0.port, isTCP: false, publicKey: $0.publicKey)
                case .TCP:
                    return OCTTox.checkBootstrapNode($0.server, port: $0.port, isTCP: true, publicKey: $0.publicKey)
                }
                } != nil
            : false
        
        guard customerNodesAvaliable == false else {
            return true
        }
        
        let nodes = ToxNodes.retrieve().nodes
        let avaliableNode = nodes.first { checkUDP($0) || checkTCP($0) }
        return avaliableNode != nil
    }
}
