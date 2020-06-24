//
//  DiscBurningItem.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class DiscBurningItem: ConcreteStorageItemType {
    typealias StorageItem = DiscBurningItem
    typealias ItemType = DiscBurningItem

    static var isNested: Bool = false
    var storageItemType: String = "DiscBurning"
    var dataType: SPDataType = .discBurning
    var serialNumber: String
    var isSSD: Bool = false
    var name: String = "Indeterminate"
    var size: String = "Indeterminate"
    var manufacturer: String = "Apple"
    var rawSize: Double = 0.0
    var rawSizeUnit: String = "KB"

    var description: String {
        return "\(storageItemType): \(serialNumber)"
    }

    // MARK: Initializer
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.serialNumber = try container.decode(String.self, forKey: .serialNumber).condenseWhitespace()
        self.name = try container.decode(String.self, forKey: .name).condenseWhitespace()

        if let manufacturer = self.name.split(separator: " ").first {
            self.manufacturer = String(manufacturer).lowercased().capitalized
        }
    }

    subscript(key: String) -> String {
        if key == "serialNumber" {
            return self.serialNumber
        }
        return String()
    }

    // MARK: Coding Keys (Codable)
    private enum CodingKeys: String, CodingKey {
        case serialNumber = "device_serial"
        case size = "size"
        case name = "_name"
    }
}
