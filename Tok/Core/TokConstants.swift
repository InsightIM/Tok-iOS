//
//  TokConstants.swift
//  Tok
//
//  Created by Bryce on 2019/9/9.
//  Copyright © 2019 Insight. All rights reserved.
//

let verifiedGroupShareIds: [String?] = ["#1F458431EB799155642",
                                        "#889802F74FD65064134",
                                        "#1791C5FFA3FDC873431"]

func performAsynchronouslyOnMainThread(_ work: @escaping (() -> Void)) {
    if Thread.isMainThread {
        work()
    } else {
        DispatchQueue.main.async(execute: work)
    }
}

func performSynchronouslyOnMainThread<T>(_ work: (() -> T)) -> T {
    if Thread.isMainThread {
        return work()
    } else {
        return DispatchQueue.main.sync(execute: work)
    }
}

extension NSNotification.Name {
    static let NewMessagesDidReceive = NSNotification.Name("com.insight.received.new.messages")
}
