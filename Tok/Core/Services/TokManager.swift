//
//  TokManager.swift
//  Tok
//
//  Created by Bryce on 2019/8/6.
//  Copyright © 2019 Insight. All rights reserved.
//

import RxSwift
import RxCocoa
import RxSwiftExt
import Foundation

@objc
protocol TokManagerDelegate: class {
    @objc optional func messageReceived(message: Data, type: OCTToxMessageType, friendNumber: OCTToxFriendNumber)
    @objc optional func messageDelivered(messageId: OCTToxMessageId, friendNumber: OCTToxFriendNumber)
    @objc optional func groupMessageReceived(friendNumber: OCTToxFriendNumber, groupCmd: OCTToxGroupCmd, messageData: Data)
    @objc optional func strangerMessageReceived(friendNumber: OCTToxFriendNumber, strangerCmd: OCTToxStrangerCmd, messageData: Data)
    @objc optional func offlineMessageReceived(friendNumber: OCTToxFriendNumber, offlineCmd: OCTToxMessageOfflineCmd, messageData: Data)
    @objc optional func fileMessageReceived(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, kind: OCTToxFileKind, fileSize: OCTToxFileSize, fileName: Data?)
    @objc optional func fileControlReceived(control: OCTToxFileControl, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber)
    @objc optional func fileChunkReceived(chunk: Data?, fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, position: OCTToxFileSize)
    @objc optional func fileChunkRequest(fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, position: OCTToxFileSize, length: Int)
}

class TokManager: NSObject, OCTToxDelegate {
    weak var delegate: TokManagerDelegate?
    
    var toxManager: OCTManager!
    let fileManager: TokFileManager
    init(profileName: String) {
        self.fileManager = TokFileManager(fileName: profileName)
    }
    
    deinit {
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
    
    var tox: OCTTox {
        return toxManager.managerGetTox()
    }
    
    func tox(_ tox: OCTTox!, messageDelivered messageId: OCTToxMessageId, friendNumber: OCTToxFriendNumber) {
        delegate?.messageDelivered?(messageId: messageId, friendNumber: friendNumber)
    }
    
    func tox(_ tox: OCTTox!, friendMessage message: Data!, type: OCTToxMessageType, friendNumber: OCTToxFriendNumber) {
        delegate?.messageReceived?(message: message, type: type, friendNumber: friendNumber)
    }
    
    func tox(_ tox: OCTTox!, friendNumber: OCTToxFriendNumber, groupCmd: OCTToxGroupCmd, messageData: Data!, length: Int) {
        delegate?.groupMessageReceived?(friendNumber: friendNumber, groupCmd: groupCmd, messageData: messageData)
    }
    
    func tox(_ tox: OCTTox!, friendNumber: OCTToxFriendNumber, strangerCmd: OCTToxStrangerCmd, messageData: Data!, length: Int) {
        delegate?.strangerMessageReceived?(friendNumber: friendNumber, strangerCmd: strangerCmd, messageData: messageData)
    }
    
    func tox(_ tox: OCTTox!, friendNumber: OCTToxFriendNumber, offlineCmd: OCTToxMessageOfflineCmd, messageData: Data!, length: Int) {
        delegate?.offlineMessageReceived?(friendNumber: friendNumber, offlineCmd: offlineCmd, messageData: messageData)
    }
    
    func tox(_ tox: OCTTox!, fileReceive control: OCTToxFileControl, friendNumber: OCTToxFriendNumber, fileNumber: OCTToxFileNumber) {
        delegate?.fileControlReceived?(control: control, friendNumber: friendNumber, fileNumber: fileNumber)
    }
    
    func tox(_ tox: OCTTox!, fileReceiveChunk chunk: Data?, fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, position: OCTToxFileSize) {
        delegate?.fileChunkReceived?(chunk: chunk, fileNumber: fileNumber, friendNumber: friendNumber, position: position)
    }
    
    func tox(_ tox: OCTTox!, fileChunkRequestForFileNumber fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, position: OCTToxFileSize, length: Int) {
        delegate?.fileChunkRequest?(fileNumber: fileNumber, friendNumber: friendNumber, position: position, length: length)
    }
    
    func tox(_ tox: OCTTox!, fileReceiveForFileNumber fileNumber: OCTToxFileNumber, friendNumber: OCTToxFriendNumber, kind: OCTToxFileKind, fileSize: OCTToxFileSize, fileName: Data!) {
        delegate?.fileMessageReceived?(fileNumber: fileNumber, friendNumber: friendNumber, kind: kind, fileSize: fileSize, fileName: fileName)
    }
}

class TokManagerDelegateProxy: DelegateProxy<TokManager, TokManagerDelegate>, DelegateProxyType, TokManagerDelegate {
    
    /// Typed parent object.
    public weak private(set) var tokManager: TokManager?
    
    /// - parameter scrollView: Parent object for delegate proxy.
    public init(tokManager: ParentObject) {
        self.tokManager = tokManager
        super.init(parentObject: tokManager, delegateProxy: TokManagerDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register { TokManagerDelegateProxy(tokManager: $0) }
    }
    
    static func currentDelegate(for object: TokManager) -> TokManagerDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: TokManagerDelegate?, to object: TokManager) {
        object.delegate = delegate
    }
}

extension Reactive where Base: TokManager {
    internal var delegate: DelegateProxy<TokManager, TokManagerDelegate> {
        return TokManagerDelegateProxy.proxy(for: base)
    }
    
    func messageDelived() -> Observable<(OCTToxMessageId, OCTToxFriendNumber)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.messageDelivered(messageId:friendNumber:)))
            .map {
                (OCTToxMessageId(($0[0] as! NSNumber).int64Value), OCTToxFriendNumber(($0[1] as! NSNumber).intValue))
        }
    }
    
    func messageReceived() -> Observable<(Data, OCTToxFriendNumber)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.messageReceived(message:type:friendNumber:)))
            .filterMap {
                guard let type = OCTToxMessageType(rawValue: ($0[1] as! NSNumber).intValue) else {
                    return .ignore
                }
                guard [OCTToxMessageType.normal, OCTToxMessageType.action].contains(type) else {
                    return .ignore
                }
                return .map(($0[0] as! Data, OCTToxFriendNumber(($0[2] as! NSNumber).intValue)))
        }
    }
    
    func groupMessageReceived() -> Observable<(OCTToxGroupCmd, Data)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.groupMessageReceived(friendNumber:groupCmd:messageData:)))
            .compactMap {
                guard let number = $0[1] as? NSNumber,
                    let cmd = OCTToxGroupCmd(rawValue: number.intValue) else {
                    return nil
                }
                return (cmd, $0[2] as! Data)
        }
    }
    
    func offlineMessageReceived() -> Observable<(OCTToxFriendNumber, OCTToxMessageOfflineCmd, Data)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.offlineMessageReceived(friendNumber:offlineCmd:messageData:)))
            .compactMap {
                guard let number = $0[1] as? NSNumber,
                    let cmd = OCTToxMessageOfflineCmd(rawValue: number.intValue) else {
                        return nil
                }
                return (OCTToxFriendNumber(($0[0] as! NSNumber).intValue), cmd, $0[2] as! Data)
        }
    }
    
    func strangerMessageReceived() -> Observable<(OCTToxStrangerCmd, Data)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.strangerMessageReceived(friendNumber:strangerCmd:messageData:)))
            .compactMap {
                guard let number = $0[1] as? NSNumber,
                    let cmd = OCTToxStrangerCmd(rawValue: number.intValue) else {
                        return nil
                }
                return (cmd, $0[2] as! Data)
        }
    }
    
    func fileMessageReceived() -> Observable<(OCTToxFileNumber, OCTToxFriendNumber, OCTToxFileKind, OCTToxFileSize, Data?)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.fileMessageReceived(fileNumber:friendNumber:kind:fileSize:fileName:)))
            .subscribeOn(MainScheduler.instance)
            .map {
                (OCTToxFileNumber(($0[0] as! NSNumber).intValue),
                 OCTToxFriendNumber(($0[1] as! NSNumber).intValue),
                 OCTToxFileKind(rawValue: ($0[2] as! NSNumber).intValue) ?? .data,
                 OCTToxFileSize(($0[3] as! NSNumber).doubleValue),
                 $0[4] as? Data)
        }
    }
    
    func fileControlReceived() -> Observable<(OCTToxFileControl, OCTToxFriendNumber, OCTToxFileNumber)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.fileControlReceived(control:friendNumber:fileNumber:)))
            .compactMap {
                guard let control = OCTToxFileControl(rawValue: ($0[0] as! NSNumber).intValue) else {
                    return nil
                }
                return (control,
                        OCTToxFriendNumber(($0[1] as! NSNumber).intValue),
                        OCTToxFileNumber(($0[2] as! NSNumber).intValue))
        }
    }
    
    func fileChunkReceived() -> Observable<(Data?, OCTToxFileNumber, OCTToxFriendNumber, OCTToxFileSize)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.fileChunkReceived(chunk:fileNumber:friendNumber:position:)))
            .map {
                ($0[0] as? Data,
                 OCTToxFileNumber(($0[1] as! NSNumber).intValue),
                 OCTToxFriendNumber(($0[2] as! NSNumber).intValue),
                 OCTToxFileSize(($0[3] as! NSNumber).doubleValue))
        }
    }
    
    func fileChunkRequest() -> Observable<(OCTToxFileNumber, OCTToxFriendNumber, OCTToxFileSize, UInt)> {
        return delegate.methodInvoked(#selector(TokManagerDelegate.fileChunkRequest(fileNumber:friendNumber:position:length:)))
            .map {
                (OCTToxFileNumber(($0[0] as! NSNumber).intValue),
                 OCTToxFriendNumber(($0[1] as! NSNumber).intValue),
                 OCTToxFileSize(($0[2] as! NSNumber).doubleValue),
                 ($0[3] as! NSNumber).uintValue)
        }
    }
}
