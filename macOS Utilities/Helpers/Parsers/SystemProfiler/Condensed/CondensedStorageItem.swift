//
//  CondensedStorageItem.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedStorageItem: Encodable {
    var deviceSerialNumber: String
    var storageItemType: String
    var storageDeviceSize: Double?
    var storageDeviceSizeUnit: String?
    var manufacturer: String
    var isDiscDrive: Bool = false
    var isSDD: Bool = false
    var model: String

    init(from storageItem: StorageItem) {
        self.deviceSerialNumber = storageItem.serialNumber

        if storageItem.size != "Indeterminate" {
            self.storageDeviceSize = storageItem.rawSize
        } else {
            self.isDiscDrive = true
        }

        if storageItem.storageItemType == "SerialATA" {
            self.storageItemType = "SATA"
        } else {
            self.storageItemType = "NVMe"
        }

        self.storageDeviceSizeUnit = storageItem.rawSizeUnit
        self.isSDD = storageItem.isSSD
        self.model = storageItem.name
        self.manufacturer = storageItem.manufacturer
    }

    enum CodingKeys: String, CodingKey {
        case deviceSerialNumber = "serialNumber"
        case storageItemType = "connection"
        case storageDeviceSize = "size"
        case storageDeviceSizeUnit = "unit"
        case isDiscDrive = "discDrive"
        case manufacturer, model
    }
}
