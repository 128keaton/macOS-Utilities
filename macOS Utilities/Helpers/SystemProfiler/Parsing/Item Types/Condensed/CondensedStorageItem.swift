//
//  CondensedStorageItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedStorageItem: Encodable {
    var deviceSerialNumber: String
    var storageItemType: String
    var storageDeviceSize: Double?
    var manufacturer: String
    var isDiscDrive: Bool = false
    var isSDD: Bool = false
    var model: String
    
    init(from storageItem: StorageItem) {
        self.deviceSerialNumber = storageItem.deviceSerialNumber
        
        if let validSize = storageItem._size,
            let doubleSize = Double(validSize.filter("01234567890.".contains)) {
            self.storageDeviceSize = doubleSize.rounded()
        } else {
            self.isDiscDrive = true
        }
        
        if storageItem.storageItemType == "SerialATA" {
            self.storageItemType = "SATA"
        } else {
            self.storageItemType = "NVMe"
        }
        
        self.isSDD = storageItem.isSSD
        self.model = storageItem.name
        self.manufacturer = storageItem.manufacturer
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceSerialNumber = "serialNumber"
        case storageItemType = "connection"
        case storageDeviceSize = "size"
        case isDiscDrive = "discDrive"
        case manufacturer, model
    }
}
