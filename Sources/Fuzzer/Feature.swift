//
//  Feature.swift
//  Fuzzer
//
//  Created by Loïc Lecrenier on 27/05/2018.
//

public enum Feature: Equatable, Hashable {
    case indirect(Indirect)
    case edge(Edge)
    case valueProfile(Cmp)

    enum Reduced: Equatable, Hashable {
        case indirect(Indirect.Reduced)
        case edge(Edge.Reduced)
        case valueProfile(Cmp.Reduced)
    }
    
    var reduced: Reduced {
        switch self {
        case .indirect(let x):
            return .indirect(x.reduced)
        case .edge(let x):
            return .edge(x.reduced)
        case .valueProfile(let x):
            return .valueProfile(x.reduced)
        }
    }
}

extension Feature {
    var score: Double {
        switch self {
        case .indirect(_):
            return 1
        case .edge(_):
            return 1
        case .valueProfile(_):
            return 1
        }
    }
}


func scoreFromByte <T: BinaryInteger> (_ byte: T) -> UInt32 {
    if byte >= 128 { return 7 }
    if byte >= 32  { return 6 }
    if byte >= 16  { return 5 }
    if byte >= 8   { return 4 }
    if byte >= 4   { return 3 }
    if byte >= 3   { return 2 }
    if byte >= 2   { return 1 }
    return 0
}


extension Feature {
    public struct Indirect: Equatable, Hashable {
        let caller: UInt
        let callee: UInt
    
        typealias Reduced = Indirect
        var reduced: Reduced { return self }
    }
    public struct Edge: Equatable, Hashable {
        let pcguard: UInt
        let counter: UInt8
        
        init(pcguard: UInt, counter: UInt8) {
            self.pcguard = pcguard
            self.counter = counter
        }
        
        struct Reduced: Equatable, Hashable {
            let pcguard: UInt
            let intensity: UInt8
        }
        
        var reduced: Reduced {
            return Reduced(pcguard: pcguard, intensity: UInt8(scoreFromByte(counter)))
        }
    }
    
    public struct Cmp: Equatable, Hashable {
        let pc: UInt
        let arg1: UInt64
        let arg2: UInt64
        
        init(pc: UInt, arg1: UInt64, arg2: UInt64) {
            self.pc = pc
            self.arg1 = arg1
            self.arg2 = arg2
        }
        
        struct Reduced: Equatable, Hashable {
            let pc: UInt
            let argxordist: UInt8
        }
        
        var reduced: Reduced {
            return Reduced(pc: pc, argxordist: UInt8(scoreFromByte((arg1 &- arg2).nonzeroBitCount)))
        }
    }
}

extension Feature.Indirect: Comparable {
    public static func < (lhs: Feature.Indirect, rhs: Feature.Indirect) -> Bool {
        return (lhs.caller, lhs.callee) < (rhs.caller, rhs.callee)
    }
}

extension Feature.Cmp.Reduced: Comparable {
    public static func < (lhs: Feature.Cmp.Reduced, rhs: Feature.Cmp.Reduced) -> Bool {
        return (lhs.pc, lhs.argxordist) < (rhs.pc, rhs.argxordist)
    }
}

extension Feature: Codable {
    enum Kind: String, Codable {
        case indirect
        case edge
        case valueProfile
    }
    
    enum CodingKey: Swift.CodingKey {
        case kind
        case pc
        case pcguard
        case counter
        case arg1
        case arg2
        case caller
        case callee
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKey.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .indirect:
            let caller = try container.decode(UInt.self, forKey: .caller)
            let callee = try container.decode(UInt.self, forKey: .callee)
            self = .indirect(.init(caller: caller, callee: callee))
        case .edge:
            let pcguard = try container.decode(UInt.self, forKey: .pcguard)
            let counter = try container.decode(UInt8.self, forKey: .counter)
            self = .edge(.init(pcguard: pcguard, counter: counter))
        case .valueProfile:
            let pc = try container.decode(UInt.self, forKey: .pc)
            let arg1 = try container.decode(UInt64.self, forKey: .arg1)
            let arg2 = try container.decode(UInt64.self, forKey: .arg2)
            self = .valueProfile(.init(pc: pc, arg1: arg1, arg2: arg2))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKey.self)
        switch self {
        case .indirect(let x):
            try container.encode(Kind.indirect, forKey: .kind)
            try container.encode(x.caller, forKey: .caller)
            try container.encode(x.callee, forKey: .callee)
        case .edge(let x):
            try container.encode(Kind.edge, forKey: .kind)
            try container.encode(x.pcguard, forKey: .pcguard)
            try container.encode(x.counter, forKey: .counter)
        case .valueProfile(let x):
            try container.encode(Kind.valueProfile, forKey: .kind)
            try container.encode(x.pc, forKey: .pc)
            try container.encode(x.arg1, forKey: .arg1)
            try container.encode(x.arg2, forKey: .arg2)
        }
    }
}