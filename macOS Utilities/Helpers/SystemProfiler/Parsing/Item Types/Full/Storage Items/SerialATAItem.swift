//
//  SerialATAItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class SerialATAItem: StorageItem {
    static var isNested: Bool = true
    var storageItemType: String = "SerialATA"
    var dataType: SPDataType = .serialATA
    
    var deviceSerialNumber: String
    var isSSD: Bool = false
    var manufacturer: String
    var mediumType: String
    var name: String
    
    var _size: String?
    var _deviceModel: String?
    
    
    var description: String {
        return "\(storageItemType) Drive: \(size) - \(deviceSerialNumber)"
    }
    
    var size: String {
        if let validSize = _size {
            return validSize
        }
        return String()
    }
    
    var isDiscDrive: Bool {
        return _size == nil
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceSerialNumber = "device_serial"
        case _size = "size"
        case name = "_name"
        case _deviceModel = "device_model"
        case mediumType = "spsata_medium_type"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceSerialNumber = try container.decode(String.self, forKey: .deviceSerialNumber).trimmingCharacters(in: .whitespacesAndNewlines)
        self.mediumType = try container.decode(String.self, forKey: .mediumType).trimmingCharacters(in: .whitespacesAndNewlines)
        self._size = try container.decodeIfPresent(String.self, forKey: ._size)
        self._deviceModel = try container.decodeIfPresent(String.self, forKey: ._deviceModel)
        self.name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.isSSD = (mediumType == "Solid State")
        
        if let manufacturer = self.name.split(separator: " ").first {
            self.manufacturer = String(manufacturer).lowercased().capitalized
        } else {
            self.manufacturer = "Apple"
        }
    }
}

class SerialATAControllerItem: NestedItemType {
    var items: [Decodable] = []
    
    var allDrives: [SerialATAItem] {
        return (items as! [SerialATAItem]).filter { $0.size != "" && $0.deviceSerialNumber != "" }
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
