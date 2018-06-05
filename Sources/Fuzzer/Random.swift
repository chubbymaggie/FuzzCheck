
extension Rand: RandomNumberGenerator {
    public mutating func next() -> UInt64 {
        return uint64()
    }
}

public struct Rand {
    
    public var seed: UInt32
    
    public init(seed: UInt32) {
        self.seed = seed
    }
    
    mutating func next31() -> UInt32 {
        seed = 214013 &* seed &+ 2531011
        return seed >> 16 &* 0x7FFF
    }
    
    public mutating func bool() -> Bool {
        return (next31() & 0b1) == 0
    }
    
    public mutating func byte() -> UInt8 {
        return UInt8(next31() & 0xFF)
    }
    
    public mutating func int() -> Int {
        let bytes = uint64()
        return Int(bitPattern: UInt(bytes))
    }
    
    public mutating func uint16() -> UInt16 {
        return UInt16(next31() & 0x00FF)
    }
    
    public mutating func uint32() -> UInt32 {
        let l = uint16()
        let r = uint16()
        return (UInt32(l) << 16) | UInt32(r)
    }
    
    public mutating func uint64() -> UInt64 {
        let l = uint32()
        let r = uint32()
        return (UInt64(l) << 32) | UInt64(r)
    }
}

extension Rand {
    public mutating func positiveInt(_ upperBound: Int) -> Int {
        precondition(upperBound != 0, "upperBound must be greater than 0")
        return Int(uint64() % UInt64(upperBound))
    }
        
    public mutating func int(inside: Range<Int>) -> Int {
        return inside.lowerBound + positiveInt(inside.count)
    }
    public mutating func integer <I: FixedWidthInteger & UnsignedInteger> (inside: Range<I>) -> I {
        return inside.lowerBound + next(upperBound: inside.upperBound - inside.lowerBound)
    }

    public mutating func pick <C: RandomAccessCollection> (from c: C) -> C.Element where C.Index == Int {
        return c[int(inside: c.startIndex ..< c.endIndex)]
    }
    
    public mutating func weightedPickIndex <W: RandomAccessCollection> (cumulativeWeights: W) -> W.Index where W.Element: FixedWidthInteger & UnsignedInteger {
       
        let randWeight: W.Element = integer(inside: 0 ..< (cumulativeWeights.last ?? 0))
        
        switch cumulativeWeights.binarySearch(compare: { $0.compare(randWeight) }) {
        case .success(let i):
            return min(cumulativeWeights.index(before: cumulativeWeights.endIndex), cumulativeWeights.index(after: i))
        case .failure(_, let end):
            return min(cumulativeWeights.index(before: cumulativeWeights.endIndex), end)
        }
        //let randWeight = (self.integer(inside: 0 ..< cumulativeWeights.last!)) + 1
        //let i = cumulativeWeights.index(where: { $0 > randWeight })!
        //return i
    }
    public mutating func weightedPickIndex <A, B, W: RandomAccessCollection> (cumulativeWeights: W) -> W.Index where W.Element == (A, B), B: FixedWidthInteger & UnsignedInteger {
        
        let randWeight: B = integer(inside: 0 ..< (cumulativeWeights.last?.1 ?? 0))
        
        switch cumulativeWeights.binarySearch(compare: { $0.1.compare(randWeight) }) {
        case .success(let i):
            return min(cumulativeWeights.index(before: cumulativeWeights.endIndex), cumulativeWeights.index(after: i))
        case .failure(_, let end):
            return min(cumulativeWeights.index(before: cumulativeWeights.endIndex), end)
        }
        //let randWeight = (self.integer(inside: 0 ..< cumulativeWeights.last!)) + 1
        //let i = cumulativeWeights.index(where: { $0 > randWeight })!
        //return i
    }
    
    public mutating func weightedPickIndex <A, B, W: RandomAccessCollection> (smallCumulativeWeights: W) -> W.Index where W.Element == (A, B), B: FixedWidthInteger & UnsignedInteger {
        
        let randWeight: B = integer(inside: 0 ..< (smallCumulativeWeights.last?.1 ?? 0))
        
        return smallCumulativeWeights.firstIndex(where: { $0.1 >= randWeight })!
        /*
        switch cumulativeWeights.binarySearch(compare: { $0.1.compare(randWeight) }) {
        case .success(let i):
            return min(cumulativeWeights.index(before: cumulativeWeights.endIndex), cumulativeWeights.index(after: i))
        case .failure(_, let end):
            return min(cumulativeWeights.index(before: cumulativeWeights.endIndex), end)
        }*/
        //let randWeight = (self.integer(inside: 0 ..< cumulativeWeights.last!)) + 1
        //let i = cumulativeWeights.index(where: { $0 > randWeight })!
        //return i
    }
    
    
    public mutating func weightedPick <T, C: RandomAccessCollection> (from c: C) -> T where C.Element == (T, UInt64), C.Index == Int {
        return c[weightedPickIndex(cumulativeWeights: c)].0
    }
    
    // precondition: c is not empty
    public mutating func arrayWeightedPick <T> (fromSmall c: [(T, UInt64)]) -> T {
        precondition(!c.isEmpty)
        // integer(inside: 0 ..< (smallCumulativeWeights.last!.1))
        /*
        let randWeight: UInt64 = uint64() % c[c.endIndex &- 1].1
        for i in c.indices {
            if c[i].1 >= randWeight { return c[i].0 }
        }
        fatalError()*/
        
        return c.withUnsafeBufferPointer { b in
            var i = b.baseAddress.unsafelyUnwrapped
            let randWeight: UInt64 = uint64() % (i + (b.count &- 1)).pointee.1
            let last = i + b.count
            while i < last {
                if i.pointee.1 >= randWeight {
                    return i.pointee.0
                }
                i = i + 1
            }
            fatalError()
        }
    }
    public mutating func weightedPick <T, C: RandomAccessCollection> (fromSmall c: C) -> T where C.Element == (T, UInt64), C.Index == Int {
        
        let randWeight: UInt64 = uint64() % c.last!.1// integer(inside: 0 ..< (smallCumulativeWeights.last!.1))
        
        for (x, y) in c {
            if y >= randWeight {
                return x
            }
        }
        fatalError()
        //return c[weightedPickIndex(smallCumulativeWeights: c)].0
    }
    /*
    public mutating func slice <C: RandomAccessCollection> (of c: C, maxLength: Int) -> C.SubSequence where C.Index == Int {
        guard !c.isEmpty else { return c[c.startIndex ..< c.startIndex] }
        let start = int(inside: c.startIndex ..< c.endIndex)
        let end = 1 + int(inside: start ..< min(c.endIndex, start + maxLength))
        precondition(start != end)
        return c[start..<end]
    }
    public mutating func prefix <C: RandomAccessCollection> (of c: C, maxLength: Int) -> C.SubSequence where C.Index == Int {
        let end = int(inside: c.startIndex ..< min(c.endIndex, c.startIndex + maxLength + 1))
        return c[..<end]
    }
    public mutating func pick <T> (_ ts: T...) -> T {
        return pick(from: ts)
    }*/
}

extension Rand {
    mutating func shuffle <C> (_ c: inout C) where C: MutableCollection, C: RandomAccessCollection, C.Indices == CountableRange<Int> {
        guard !c.isEmpty else { return }
        for i in (0 ..< c.count).reversed() {
            c.swapAt(int(inside: 0 ..< i+1), i)
        }
    }
}

extension Sequence {
    public func scan <T> (_ initial: T, _ acc: (T, Element) -> T) -> [T] {
        var results: [T] = []
        var t = initial
        for x in self {
            t = acc(t, x)
            results.append(t)
        }
        return results
    }
}

//
//  BinarySearch.swift
//  MarkdownEditHelpersPackageDescription
//
//  Created by Loïc Lecrenier on 29/12/2017.
//

public enum BinarySearchOrdering {
    case less
    case match
    case greater
}

extension BinarySearchOrdering {
    public var opposite: BinarySearchOrdering {
        switch self {
        case .less:
            return .greater
        case .match:
            return .match
        case .greater:
            return .less
        }
    }
}


extension RandomAccessCollection {
    public func binarySearch(
        compare: (Element) -> BinarySearchOrdering
        ) -> BinarySearchResult<Index> {
        var beforeBound = startIndex
        var startSearch = startIndex
        var endSearch = endIndex
        
        while startSearch != endSearch {
            let mid = self.index(startSearch, offsetBy: distance(from: startSearch, to: endSearch) / 2)
            let candidate = self[mid]
            switch compare(candidate) {
            case .less:
                beforeBound = mid
                startSearch = index(after: mid)
            case .match:
                return .success(mid)
            case .greater:
                endSearch = mid
            }
        }
        return .failure(start: beforeBound, end: endSearch)
    }
}

public enum BinarySearchResult <Index> {
    case success(Index)
    case failure(start: Index, end: Index)
}

extension BinarySearchResult {
    public var asOptional: Index? {
        switch self {
        case .success(let i):
            return i
        case .failure(_):
            return nil
        }
    }
}

extension Range {
    public func compare(_ element: Bound) -> BinarySearchOrdering {
        if lowerBound > element {
            return .greater
        } else if upperBound <= element {
            return .less
        } else {
            return .match
        }
    }
}

extension Comparable {
    public func compare(_ element: Self) -> BinarySearchOrdering {
        if self > element { return .greater }
        else if self < element { return .less }
        else { return .match }
    }
}






