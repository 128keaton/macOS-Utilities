//
//  Volume.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class Volume: Item {
    var deviceIdentifier: String = ""
    var diskUUID: String = ""
    var mountPoint: String = ""
    var size: Double = 0.0
    var volumeName: String = ""
    var volumeUUID: String = ""
    var containsInstaller: Bool = false
    var installer: Installer? = nil
    var id: String = String.random(12).md5Value
    var measurementUnit: String = "GB"
    var content: String = "Apple_HFS"
    
    var description: String {
        return "Volume: \n\t Device Identifier: \(self.deviceIdentifier) \n\t Disk UUID: \(self.diskUUID)  \n\t Mount Point: \(self.mountPoint)\n\t   Volume Name: \(self.volumeName)\n\t Volume UUID: \(self.volumeUUID)\n\t  Installer: \(self.installer == nil ? "None" : self.installer!.description)\n\t   Size: \(self.size) \(self.measurementUnit) \n"
    }

    var isInstallable: Bool {
        return (measurementUnit == "GB" ? size > 150.0 : true) && content != "Apple_APFS" && content != "EFI"
    }

    init(_ volumeDictionary: NSDictionary) {
        if let deviceIdentifier = volumeDictionary["DeviceIdentifier"] as? String {
            self.deviceIdentifier = deviceIdentifier
        }

        if let diskUUID = volumeDictionary["DiskUUID"] as? String {
            self.diskUUID = diskUUID
        }

        if let mountPoint = volumeDictionary["MountPoint"] as? String {
            self.mountPoint = mountPoint
        }
        
        if let content = volumeDictionary["Content"] as? String {
            self.content = content
        }

        if let size = volumeDictionary["Size"] as? Int {
            self.size = (Double(size) / 1073741824.0).rounded()
            if(self.size > 1000.0) {
                self.measurementUnit = "TB"
                self.size = self.size / 1000.0
            }
        }

        if let volumeName = volumeDictionary["VolumeName"] as? String {
            self.volumeName = volumeName
        }

        if let volumeUUID = volumeDictionary["VolumeUUID"] as? String {
            self.volumeUUID = volumeUUID
        }

        self.checkIfContainsInstaller()
        self.addToRepo()
    }

    public func checkIfContainsInstaller(shouldUpdate: Bool = false) {
        if((self.volumeName.contains("Install OS X") || self.volumeName.contains("Install macOS")) == true && self.containsInstaller == false) {
            let potentialInstaller = Installer(volume: self)
            if(potentialInstaller.isValid) {
                self.installer = potentialInstaller
                self.containsInstaller = true
            }
        } else if(self.containsInstaller == true) {
            self.containsInstaller = false
        }

        if(shouldUpdate) {
            //  self.disk?.updateMountedDisk(mountedDisk: self)
        }
    }

    func addToRepo() {
        ItemRepository.shared.addToRepository(newVolume: self)
    }

    static func == (lhs: Volume, rhs: Volume) -> Bool {
        return lhs.id == rhs.id
    }
}
