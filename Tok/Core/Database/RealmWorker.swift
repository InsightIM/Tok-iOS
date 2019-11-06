//
//  RealmWorker.swift
//  Tok
//
//  Created by Bryce on 2019/10/16.
//  Copyright © 2019 Insight. All rights reserved.
//

import Foundation

// Performs submitted work items on a dedicated thread
class RealmWorker {
    
    // the worker thread
    private var thread: Thread?
    
    // used to put the worker thread in the sleep mode, so in won't consume
    // CPU while the queue is empty
    private let semaphore = DispatchSemaphore(value: 0)
    
    // using a lock to avoid race conditions if the worker and the enqueuer threads
    // try to update the queue at the same time
    private let lock = NSRecursiveLock()
    
    // and finally, the glorious queue, where all submitted blocks end up, and from
    // where the worker thread consumes them
    private var queue = [() -> Void]()
    
    // enqueues the given block; the worker thread will execute it as soon as possible
    public func enqueue(_ block: @escaping () -> Void) {
        // add the block to the queue, in a thread safe manner
        locked { queue.append(block) }
        
        // signal the semaphore, this will wake up the sleeping beauty
        semaphore.signal()
        
        // if this is the first time we enqueue a block, detach the thread
        // this makes the class lazy - it doesn't dispatch a new thread until the first
        // work item arrives
        if thread == nil {
            thread = Thread(block: work)
            thread?.start()
        }
    }
    
    // the method that gets passed to the thread
    private func work() {
        // just an infinite sequence of sleeps while the queue is empty
        // and block executions if the queue has items
        while true {
            // let's sleep until we get signalled that items are available
            semaphore.wait()
            
            // extract the first block in a thread safe manner, execute it
            // if we get here we know for sure that the queue has at least one element
            // as the semaphore gets signalled only when an item arrives
            let block = locked { queue.removeFirst() }
            block()
        }
    }
    
    // synchronously executes the given block in a thread-safe manner
    // returns the same value as the block
    private func locked<T>(do block: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return block()
    }
}
