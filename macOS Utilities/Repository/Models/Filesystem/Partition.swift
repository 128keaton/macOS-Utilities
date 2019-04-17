//
//  Partition.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

struct Partition: Item, Codable {
    var content: String?
    var deviceIdentifier: String
    var diskUUID: String?
    var rawSize: Int64
    var rawVolumeName: String?
    var volumeUUID: String?
    var mountPoint: String?
    var isFake: Bool = false
    var id: String {
        return volumeUUID ?? diskUUID ?? String.random(12)
    }
    var size: Units {
        return Units(bytes: self.rawSize)
    }

    var volumeName: String {
        if let absoluteVolumeName = self.rawVolumeName {
            return absoluteVolumeName
        }

        if let absoluteMountPoint = self.mountPoint {
            return String(absoluteMountPoint.split(separator: "/").last!)
        }

        return "Not mounted"
    }

    var isAPFS: Bool {
        return (self.content == nil) && (self.volumeUUID != nil) || self.content == "Apple_APFS"
    }

    var canErase: Bool {
        var userConfirmedErase = true
        if let mainWindow = NSApplication.shared.mainWindow,
            let contentViewController = mainWindow.contentViewController {
            userConfirmedErase = contentViewController.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(self.volumeName)? This will make all the data on \(self.volumeName) unrecoverable.")
        }
        
        return !self.containsInstaller && userConfirmedErase
    }

    var description: String {
        var aDescription = "\n\t\tPartition \(self.id) \n\t\t\tDevice Identifier: \(deviceIdentifier)\n"
        aDescription += "\n\t\t\tContent: \(self.content ?? "None")"
        aDescription += "\n\t\t\tSize: \(self.size.gigabytes) GB"
        aDescription += "\n\t\t\tVolume Name: \(self.volumeName)"
        aDescription += "\n\t\t\tMount Point: \(self.mountPoint ?? "Not mounted")\n"
        aDescription += "\n\t\t\tMounted: \(self.isMounted)\n"

        return aDescription
    }

    var installable: Bool {
        return self.size.gigabytes >= 120.0 && self.volumeName != "System Reserved" && self.isMounted
    }

    var containsInstaller: Bool {
        if let mountPoint = self.mountPoint {
            return mountPoint.contains("Install macOS") || mountPoint.contains("Install OS X")
        }
        return false
    }

    var isMounted: Bool {
        return self.mountPoint != nil
    }

    func addToRepo() {
        ItemRepository.shared.addToRepository(newPartition: self)
    }

    func getMountPoint() -> String {
        return self.mountPoint ?? "Not mounted"
    }

    public func erase(newName: String? = nil, forInstaller: Installer? = nil, returnCompletion: @escaping (Bool, String?) -> ()){
        DiskUtility.shared.erase(self, newName: newName, forInstaller: forInstaller) { (didComplete, newDiskName) in
            returnCompletion(didComplete, newDiskName)
        }
    }
    
    static func == (lhs: Partition, rhs: Partition) -> Bool {
        return lhs.volumeUUID == rhs.volumeUUID && lhs.diskUUID == rhs.diskUUID
    }

    private enum CodingKeys: String, CodingKey {
        case content = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case diskUUID = "DiskUUID"
        case rawSize = "Size"
        case rawVolumeName = "VolumeName"
        case volumeUUID = "VolumeUUID"
        case mountPoint = "MountPoint"
    }
}
