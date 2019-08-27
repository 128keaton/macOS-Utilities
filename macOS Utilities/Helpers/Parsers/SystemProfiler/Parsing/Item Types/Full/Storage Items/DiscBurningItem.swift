//
//  DiscBurningItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class DiscBurningItem: StorageItem {
    static var isNested: Bool = false
    var manufacturer: String
    var name: String
    var storageItemType: String = "DiscBurning"
    var dataType: SPDataType = .discBurning
    
    var deviceSerialNumber: String
    var isSSD: Bool = false
    
    var _size: String? = nil
    var _deviceModel: String?
    
    var description: String {
        return "\(storageItemType): \(deviceSerialNumber)"
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceSerialNumber = "device_serial"
        case _deviceModel = "device_model"
        case name = "_name"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceSerialNumber = try container.decode(String.self, forKey: .deviceSerialNumber).trimmingCharacters(in: .whitespacesAndNewlines)
        self._deviceModel = try container.decodeIfPresent(String.self, forKey: ._deviceModel)
        self.name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let manufacturer = self.name.split(separator: " ").first {
            self.manufacturer = String(manufacturer).lowercased().capitalized
        } else {
            self.manufacturer = "Apple"
        }
    }
}
