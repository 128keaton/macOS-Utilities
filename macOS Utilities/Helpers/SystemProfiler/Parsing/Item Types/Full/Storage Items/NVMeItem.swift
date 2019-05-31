//
//  NVMeItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
class NVMeItem: StorageItem {
    static var isNested: Bool = false
    var isSSD: Bool = true
    
    var storageItemType: String = "NVMe"
    var dataType: SPDataType = .NVMe
    
    var deviceSerialNumber: String
    var manufacturer: String
    var name: String
    
    var _size: String?
    var _deviceModel: String?
    
    var description: String {
        return "\(storageItemType): \(size) - \(deviceSerialNumber)"
    }
    
    var size: String {
        if let validSize = _size {
            return validSize
        }
        return String()
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceSerialNumber = "device_serial"
        case _size = "size"
        case name = "_name"
        case _deviceModel = "device_model"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceSerialNumber = try container.decode(String.self, forKey: .deviceSerialNumber).trimmingCharacters(in: .whitespacesAndNewlines)
        self._deviceModel = try container.decodeIfPresent(String.self, forKey: ._deviceModel)
        self._size = try container.decodeIfPresent(String.self, forKey: ._size)
        self.name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let manufacturer = self.name.split(separator: " ").first {
            self.manufacturer = String(manufacturer).lowercased().capitalized
        } else {
            self.manufacturer = "Apple"
        }
    }
}
