//
//  MemoryItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct MemoryItem: ConcreteItemType {
    typealias ItemType = MemoryItem
    
    static var isNested: Bool = true
    var dataType: SPDataType = .memory
    var description: String {
        return "\(size) - \(speed) - \(type) - \(status == "ok" ? "Good" : "Bad")"
    }
    
    var size: String
    var speed: String
    var status: String
    var type: String
    
    enum CodingKeys: String, CodingKey {
        case size = "dimm_size"
        case speed = "dimm_speed"
        case status = "dimm_status"
        case type = "dimm_type"
    }
}

class NestedMemoryItem: NestedItemType {
    var description: String {
        return "\(items)"
    }
    
    var items: [Decodable] = []
    
    private var _isECC: String
    private var _isUpgradable: String
    
    var isECC: Bool {
        get {
            return _isECC == "ecc_enabled"
        }
        set {
            _isECC = newValue ? "ecc_enabled" : "ecc_disabled"
        }
    }
    
    var isUpgradable: Bool {
        get {
            return _isUpgradable == "Yes"
        }
        set {
            _isUpgradable = newValue ? "Yes" : "No"
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let memoryItems = try container.decodeIfPresent([MemoryItem].self, forKey: .items)
        
        self._isECC = try container.decode(String.self, forKey: ._isECC)
        self._isUpgradable = try container.decode(String.self, forKey: ._isUpgradable)
        
        if memoryItems != nil {
            self.items = memoryItems! as [Decodable]
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case items = "_items"
        case _isECC = "global_ecc_state"
        case _isUpgradable = "is_memory_upgradeable"
    }
}
