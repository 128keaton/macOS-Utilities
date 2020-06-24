//
//  NVMeItem.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
class NVMeItem: ConcreteStorageItemType {
    typealias StorageItem = NVMeItem
    typealias ItemType = NVMeItem
    
    static var isNested: Bool = false
    var storageItemType: String = "NVMe"
    var dataType: SPDataType = .NVMe
    var serialNumber: String
    var isSSD: Bool = true
    var name: String = "Indeterminate"
    var size: String = "Indeterminate"
    var manufacturer: String = "Apple"
    var rawSize: Double = 0.0
    var rawSizeUnit: String = "KB"
    
    // MARK: Item Properties
    var model: String = "Indeterminate"
    
    var description: String {
        return "\(storageItemType): \(size) - \(serialNumber)"
    }
    
    // MARK: Initializer
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.serialNumber = try container.decode(String.self, forKey: .serialNumber).condenseWhitespace()
        
        if let model = try container.decodeIfPresent(String.self, forKey: .model) {
            self.model = model
        }
        
        if let size = try container.decodeIfPresent(String.self, forKey: .size) {
            self.size = size
        }
        
        if let manufacturer = self.name.split(separator: " ").first {
            self.manufacturer = String(manufacturer).lowercased().capitalized
        }
        
        self.rawSize = Size.rawValue(self.size)
        self.rawSizeUnit = self.size.components(separatedBy: CharacterSet.decimalDigits).joined().replacingOccurrences(of: ".", with: "").condenseWhitespace()
    }
    
    // MARK: Coding Keys (Codable)
    private enum CodingKeys: String, CodingKey {
        case serialNumber = "device_serial"
        case size = "size"
        case name = "_name"
        case model = "device_model"
    }
    
    subscript(key: String) -> String {
        if key == "size" {
            return String(self.rawSize)
        } else if key == "model" {
            return self.model
        } else if key == "serialNumber" {
            return self.serialNumber
        }
        return String()
    }
}
