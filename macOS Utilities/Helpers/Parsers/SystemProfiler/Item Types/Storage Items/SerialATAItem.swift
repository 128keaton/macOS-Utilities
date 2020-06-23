//
//  SerialATAItem.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class SerialATAItem: ConcreteStorageItemType {
    typealias StorageItem = SerialATAItem
    typealias ItemType = SerialATAItem
    
    
    // MARK: StorageItem
    static var isNested: Bool = true
    var storageItemType: String = "SerialATA"
    var dataType: SPDataType = .serialATA
    var serialNumber: String
    var isSSD: Bool = false
    var name: String = "Indeterminate"
    var size: String = "Indeterminate"
    var manufacturer: String = "Apple"
    var rawSize: Double = 0.0
    var rawSizeUnit: String = "KB"
    
    // MARK: Item Properties
    var mediumType: String = "Indeterminate"
    var model: String = "Indeterminate"
    
    var description: String {
        return "\(storageItemType) Drive: \(size) - \(serialNumber)"
    }
    
    var isDiscDrive: Bool {
        return size == "Indeterminate" && mediumType == "Indeterminate"
    }
    
    // MARK: Initializer
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.serialNumber = try container.decode(String.self, forKey: .serialNumber).condenseWhitespace()
        self.name = try container.decode(String.self, forKey: .name).condenseWhitespace()
        
        if let model = try container.decodeIfPresent(String.self, forKey: .model) {
            self.model = model
        }
        
        if let size = try container.decodeIfPresent(String.self, forKey: .size) {
            self.size = size
        }
        
        if let rawMediumType = try container.decodeIfPresent(String.self, forKey: .mediumType) {
            self.mediumType = rawMediumType.condenseWhitespace()
            self.isSSD = (self.mediumType == "Solid State")
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
        case mediumType = "spsata_medium_type"
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

class SerialATAControllerItem: NestedItemType {
    var items: [Decodable] = []
    
    var allDrives: [SerialATAItem] {
        return (items as! [SerialATAItem]).filter { $0.size != "" && $0.serialNumber != "" }
    }
    
    var allDiscDrives: [SerialATAItem] {
        return (items as! [SerialATAItem]).filter { $0.isDiscDrive }
    }
    
    var hasDrives: Bool {
        return allDrives.count > 0
    }
    
    var hasDiscDrive: Bool {
        return allDiscDrives.count > 0
    }
    
    enum CodingKeys: String, CodingKey {
        case items = "_items"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let serialATAItems = try container.decodeIfPresent([SerialATAItem].self, forKey: .items) {
            self.items = serialATAItems as [Decodable]
        }
    }
}
