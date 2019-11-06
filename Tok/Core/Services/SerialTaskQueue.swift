//
//  SerialTaskQueue.swift
//  Tok
//
//  Created by Bryce on 2019/6/15.
//  Copyright © 2019 Insight. All rights reserved.
//

import RxSwift

final class SerialTaskQueue {
    public private(set) var isBusy = false
    private let disposeBag = DisposeBag()
    private var tasksQueue = [Observable<Void>]()
    
    init() {}
    
    func addTask(_ task: Observable<Void>) {
        let runInMainThread = {
            self.tasksQueue.append(task)
            self.maybeExecuteNextTask()
        }
        if Thread.isMainThread {
            runInMainThread()
        } else {
            DispatchQueue.main.async {
                runInMainThread()
            }
        }
    }
    
    func start() {
        maybeExecuteNextTask()
    }
    
    func flushQueue() {
        tasksQueue.removeAll()
    }
    
    var isEmpty: Bool {
        return tasksQueue.isEmpty
    }
    
    func maybeExecuteNextTask() {
        guard !isEmpty else {
            return
        }
        guard !isBusy else {
            return
        }
        isBusy = true
        
        let task = self.tasksQueue.removeFirst()
        task
            .observeOn(MainScheduler.instance)
            .subscribe(onDisposed: { [weak self] in
                self?.isBusy = false
                self?.maybeExecuteNextTask()
            })
            .disposed(by: disposeBag)
    }
}

