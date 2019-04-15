import Foundation

/*
 An ordered array. When you add a new item to this array, it is inserted in
 sorted position.
 */
public struct OrderedArray<T: Comparable> {
    private(set) var array: [T]
    
    public init(array: [T]) {
        self.array = array
        self.array.sort()
    }
    
    public init() {
        self.array = []
    }
    
    public var isEmpty: Bool {
        return array.isEmpty
    }
    
    public var count: Int {
        return array.count
    }
    
    public subscript(index: Int) -> T {
        return array[index]
    }
    
    @discardableResult
    public mutating func remove(at index: Int) -> T {
        return array.remove(at: index)
    }
    
    public mutating func removeAll() {
        array.removeAll()
    }
    
    @discardableResult
    public mutating func insert(newElement: T) -> Int {
        let i = findInsertionPoint(newElement)
        array.insert(newElement, at: i)
        return i
    }
    
    public mutating func insert(_ newElement: T, at index: Int) {
        array.insert(newElement, at: index)
    }
    
    public func findInsertionPoint(_ newElement: T) -> Int {
        var startIndex = 0
        var endIndex = array.count
        
        while startIndex < endIndex {
            let midIndex = startIndex + (endIndex - startIndex) / 2
            if array[midIndex] == newElement {
                return midIndex
            } else if array[midIndex] < newElement {
                startIndex = midIndex + 1
            } else {
                endIndex = midIndex
            }
        }
        return startIndex
    }
}

extension OrderedArray: CustomStringConvertible {
    public var description: String {
        return array.description
    }
}
