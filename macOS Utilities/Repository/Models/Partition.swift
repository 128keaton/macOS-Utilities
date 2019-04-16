//
//  Partition.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

struct Partition: Codable, Item {
    var content: String?
    var deviceIdentifier: String
    var diskUUID: String?
    var size: Int64
    var volumeName: String?
    var volumeUUID: String?
    var mountPoint: String?
    var id: String {
        return volumeUUID ?? diskUUID ?? String.random(12)
    }

    var description: String {
        var aDescription = "\n\t\tPartition \(self.id) \n\t\t\tDevice Identifier: \(deviceIdentifier)\n"
        aDescription += "\n\t\t\tContent: \(self.content ?? "None")"
        aDescription += "\n\t\t\tSize: \(self.size)kb"
        aDescription += "\n\t\t\tVolume Name: \(self.volumeName ?? "None")"
        aDescription += "\n\t\t\tMount Point: \(self.mountPoint ?? "Not mounted")\n"
        
        return aDescription
    }
    
    var containsInstaller: Bool {
        if let mountPoint = self.mountPoint{
            return mountPoint.contains("Install macOS") || mountPoint.contains("Install OS X")
        }
        return false
    }
    
    var isMounted: Bool {
        return self.volumeName != nil && self.mountPoint != nil
    }

    func addToRepo() {
        print(self)
    }

    func getVolumeName() -> String{
        return self.volumeName ?? "Not mounted"
    }
    
    func getMountPoint() -> String{
        return self.mountPoint ?? "Not mounted"
    }
    
    static func == (lhs: Partition, rhs: Partition) -> Bool {
        return lhs.volumeUUID == rhs.volumeUUID && lhs.diskUUID == rhs.diskUUID
    }

    private enum CodingKeys: String, CodingKey {
        case content = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case diskUUID = "DiskUUID"
        case size = "Size"
        case volumeName = "VolumeName"
        case volumeUUID = "VolumeUUID"
        case mountPoint = "MountPoint"
    }
}
