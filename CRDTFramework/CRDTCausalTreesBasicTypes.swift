//
//  CRDTCausalTreesBasicTypes.swift
//  CRDTPlayground
//
//  Created by Alexei Baboulevitch on 2017-9-18.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import Foundation

public protocol DefaultInitializable { init() }
public protocol Zeroable { static var zero: Self { get } }

public protocol CausalTreeAtomPrintable { var atomDescription: String { get } }
public protocol CausalTreeSiteUUIDT: DefaultInitializable, CustomStringConvertible, Hashable, Zeroable, Comparable, Codable {}
public protocol CausalTreeValueT: DefaultInitializable, CausalTreeAtomPrintable, Codable {}

// TODO: rename these to be less generic

public typealias SiteId = Int16
public typealias Clock = Int64
public typealias ArrayType = Array //AB: ContiguousArray makes me feel safer, but is not Codable by default :(

public typealias YarnIndex = Int32
public typealias WeaveIndex = Int32
public typealias AllYarnsIndex = Int32 //TODO: this is underused -- mistakenly use YarnsIndex

// no other atoms can have these clock numbers
public let ControlSite: SiteId = SiteId(0)
public let StartClock: Clock = Clock(1)
public let EndClock: Clock = Clock(2)
public let NullSite: SiteId = SiteId(SiteId.max)
public let NullClock: Clock = Clock(0)
public let NullIndex: YarnIndex = -1 //max (NullIndex, index) needs to always return index
public let NullAtomId: AtomId = AtomId(site: NullSite, index: NullIndex)

public struct AtomId: Equatable, Comparable, CustomStringConvertible, Codable
{
    public let site: SiteId
    public let index: YarnIndex
    
    public static func ==(lhs: AtomId, rhs: AtomId) -> Bool
    {
        return lhs.site == rhs.site && lhs.index == rhs.index
    }
    
    public init(site: SiteId, index: YarnIndex)
    {
        self.site = site
        self.index = index
    }
    
    public var description: String
    {
        get
        {
            if site == NullSite
            {
                return "x:x"
            }
            else
            {
                return "\(site):\(index)"
            }
        }
    }
    
    // WARNING: this does not mean anything structurally, and is just used for ordering non-causal atoms
    public static func <(lhs: AtomId, rhs: AtomId) -> Bool {
        return (lhs.site == rhs.site ? lhs.index < rhs.index : lhs.site < rhs.site)
    }
}

public enum AtomType: Int8, CustomStringConvertible, Codable
{
    case value = 1
    case valuePriority
    case commit //unordered child: appended to back of weave, since only yarn position matters
    case start
    case end
    case delete
    //case undelete
    
    public var value: Bool
    {
        return self == .value || self == .valuePriority
    }
    
    // not part of DFS ordering and output; might only use atom reference
    public var unparented: Bool
    {
        // TODO: end should probably be parented, but childless
        // AB: end is also non-causal for convenience, since we can't add anything to it and it will start off our non-causal segment
        return self == .commit || self == .end
    }
    
    // cannot cause anything; useful for invisible and control atoms
    public var childless: Bool
    {
        return self == .end || self == .delete
    }
    
    // pushed to front of child ordering, so that e.g. control atoms with specific targets are not regargeted on merge
    public var priority: Bool
    {
        return self == .delete || self == .valuePriority
    }
    
    public var description: String
    {
        switch self {
        case .value:
            return "Value"
        case .valuePriority:
            return "Value Priority"
        case .commit:
            return "Commit"
        case .start:
            return "Start"
        case .end:
            return "End"
        case .delete:
            return "Delete"
        }
    }
}

// avoids having to generify every freakin' view controller
public struct AtomMetadata
{
    public let id: AtomId
    public let cause: AtomId
    public let reference: AtomId
    public let type: AtomType
    public let timestamp: YarnIndex
}

// TODO: I don't like that this tiny structure has to be malloc'd
public struct Weft: Equatable, Comparable, CustomStringConvertible
{
    public private(set) var mapping: [SiteId:YarnIndex] = [:]
    
    public mutating func update(site: SiteId, index: YarnIndex)
    {
        if site == NullAtomId.site { return }
        mapping[site] = max(mapping[site] ?? NullIndex, index)
    }
    
    public mutating func update(atom: AtomId) {
        if atom == NullAtomId { return }
        update(site: atom.site, index: atom.index)
    }
    
    public mutating func update(weft: Weft)
    {
        for (site, index) in weft.mapping
        {
            update(site: site, index: index)
        }
    }
    
    public func included(_ atom: AtomId) -> Bool {
        if atom == NullAtomId
        {
            return true //useful default when generating causal blocks for non-causal atoms
        }
        if let index = mapping[atom.site] {
            if atom.index <= index {
                return true
            }
        }
        return false
    }
    
    // assumes that both wefts have equivalent site id maps
    // Complexity: O(S)
    public static func <(lhs: Weft, rhs: Weft) -> Bool
    {
        // remember that we can do this efficiently b/c site ids increase monotonically -- no large gaps
        let maxLhsSiteId = lhs.mapping.keys.max() ?? 0
        let maxRhsSiteId = rhs.mapping.keys.max() ?? 0
        let maxSiteId = Int(max(maxLhsSiteId, maxRhsSiteId)) + 1
        var lhsArray = Array<YarnIndex>(repeating: -1, count: maxSiteId)
        var rhsArray = Array<YarnIndex>(repeating: -1, count: maxSiteId)
        lhs.mapping.forEach { lhsArray[Int($0.key)] = $0.value }
        rhs.mapping.forEach { rhsArray[Int($0.key)] = $0.value }
        
        return lhsArray.lexicographicallyPrecedes(rhsArray)
    }
    
    public static func ==(lhs: Weft, rhs: Weft) -> Bool
    {
        return (lhs.mapping as NSDictionary).isEqual(to: rhs.mapping)
    }
    
    public var description: String
    {
        get
        {
            var string = "["
            let sites = Array<SiteId>(mapping.keys).sorted()
            for (i,site) in sites.enumerated()
            {
                if i != 0
                {
                    string += ", "
                }
                string += "\(site):\(mapping[site]!)"
            }
            string += "]"
            return string
        }
    }
}