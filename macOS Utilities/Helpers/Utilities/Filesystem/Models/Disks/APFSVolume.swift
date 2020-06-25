//
//  APFSVolume.swift
//  Shredder
//
//  Created by Keaton Burleson on 6/24/20.
//  Copyright © 2020 Pro Warehouse. All rights reserved.
//

import Foundation

// MARK: - APFSVolume
struct APFSVolume: Codable, CustomStringConvertible {
    let deviceIdentifier: String
    let mountPoint, volumeName, volumeUUID: String?
    let size: Int
    let diskUUID, content: String?
    
    var description: String {
        var base =  "APFSVolume [Size: \(self.size), Device ID: \(self.deviceIdentifier)]\n"
        
        if let mountPoint = self.mountPoint {
            base += "   Mount Point: \(mountPoint)\n"
        }
        
        if let volumeName = self.volumeName {
            base += "   Volume Name: \(volumeName)\n"
        }
        
        if let volumeUUID = self.volumeUUID {
            base += "   Volume UUID: \(volumeUUID)\n"
        }
        
        if let diskUUID = self.diskUUID {
            base += "   Disk UUID: \(diskUUID)\n"
        }
        
        if let content = self.content {
            base += "   Content: \(content)\n"
        }
        
        return base
    }

    enum CodingKeys: String, CodingKey {
        case deviceIdentifier = "DeviceIdentifier"
        case mountPoint = "MountPoint"
        case volumeName = "VolumeName"
        case volumeUUID = "VolumeUUID"
        case size = "Size"
        case diskUUID = "DiskUUID"
        case content = "Content"
    }
}
