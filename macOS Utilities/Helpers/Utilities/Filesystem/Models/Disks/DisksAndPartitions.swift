//
//  DisksAndPartitions.swift
//  Shredder
//
//  Created by Keaton Burleson on 6/24/20.
//  Copyright © 2020 Pro Warehouse. All rights reserved.
//

import Foundation

// MARK: - DisksAndPartitions
struct DisksAndPartitions: Codable, CustomStringConvertible {
    let partitions: [APFSVolume]?
    let content, deviceIdentifier: String
    let size: Int
    let apfsVolumes: [APFSVolume]?
    let apfsPhysicalStores: [APFSPhysicalStore]?
    let mountPoint, volumeName: String?

    var description: String {
        var base = "DisksAndPartitions - [Size: \(self.size)] \n"
        
        if let mountPoint = self.mountPoint {
            base += "   Mount Point: \(mountPoint)\n"
        }
        
        if let volumeName = self.volumeName {
            base += "   Volume Name: \(volumeName)\n"
        }
        
        if let partitions = self.partitions {
            base += "   Partitions: \(partitions)\n"
        }

        if let apfsVolumes = self.apfsVolumes {
            base += "   Volumes: \(apfsVolumes)\n"
        }
        
        if let apfsPhysicalStores = self.apfsPhysicalStores {
            base += "   APFS Physical Stores: \(apfsPhysicalStores)\n"
        }

        return base
    }

    enum CodingKeys: String, CodingKey {
        case partitions = "Partitions"
        case content = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case size = "Size"
        case apfsVolumes = "APFSVolumes"
        case apfsPhysicalStores = "APFSPhysicalStores"
        case mountPoint = "MountPoint"
        case volumeName = "VolumeName"
    }
}
