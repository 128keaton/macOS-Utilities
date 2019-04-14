//
//  Partition.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class Partition: Codable, Item {
    var content: String
    var deviceIdentifier: String
    var diskUUID: String
    var size: Int
    var volumeName: String? = nil
    var volumeUUID: String? = nil
    var id: String {
        return volumeUUID ?? diskUUID
    }

    var description: String {
        return "Partition \(volumeName ?? diskUUID) \(deviceIdentifier)"
    }


    func addToRepo() {
        print(self)
    }

    static func == (lhs: Partition, rhs: Partition) -> Bool {
        return lhs.volumeUUID == rhs.volumeUUID && lhs.diskUUID == rhs.diskUUID
    }
    
    init() {
        self.content = "Content"
        self.deviceIdentifier = "DeviceID"
        self.diskUUID = "DiskUUID"
        self.size = 0
        self.volumeName = nil
        self.volumeUUID = nil
    }

    private enum CodingKeys: String, CodingKey {
        case content = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case diskUUID = "DiskUUID"
        case size = "Size"
        case volumeName = "VolumeName"
        case volumeUUID = "VolumeUUID"
    }
}
