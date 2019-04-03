//
//  MountedDisk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CommonCrypto

class MountedDisk: CustomStringConvertible {
    var devEntry: String = "/dev/null"
    var name: String = "Invalid Disk"

    var size: Double = 0.0
    var measurementUnit: String = "GB"
    var isInternal: Bool = true
    var disk: Disk? = nil
    var containsInstaller: Bool = false
    var installer: Installer? = nil
    var updatedAction: DiskAction? = nil

    var mountPoint: String? {
        if self.isValid {
            return "/Volumes/\(self.name)"
        }

        return nil
    }

    var uniqueMountID: String {
        return self.name.md5Value
    }

    var isValid: Bool {
        return self.devEntry != "/dev/null" && self.name != "Not applicable (no file system)" && self.name != "Invalid Disk"
    }

    var isInstallable: Bool {
        return (self.size > 150.0 || self.measurementUnit == "TB") && isValid
    }

    var description: String {
        let baseString = "MountedDisk: \n\t Name: \(self.name) \n\t Size: \(self.size) \(self.measurementUnit)  \n\t Installable to: \(self.isInstallable) \n\t Valid: \(self.isValid) \n\t Contains Installer: \(self.containsInstaller) \n\t Mount Point: \(self.mountPoint ?? "No mount point") \n\t /dev/disk Entry: \(self.devEntry) \n\t Internal: \(self.isInternal ? "Yes" : "No")\n"
        if(containsInstaller == true) {
            return "\(baseString) \t\t \(self.installer!)"
        }

        return baseString
    }

    private var diskUtility = DiskUtility.shared

    init(existingDisk: Disk, matchedDiskOutput: String, passedName: String? = nil) {
        if let matchedSize = matchedDiskOutput.matches("([0-9]+( |.[0-9]+ )(GB|TB))", stripR: ["\\*", "\\+"]).first {
            if(matchedSize.contains("TB")) {
                self.measurementUnit = "TB"
            }

            self.size = matchedSize.doubleValue
        }

        if let matchedMountPoint = matchedDiskOutput.matches("disk([0-9]*)s.").first {
            self.devEntry = "/dev/\(matchedMountPoint)"
        }


        if let potentialName = passedName {
            self.name = potentialName
            self.checkIfContainsInstaller()
            self.disk?.mountedDisk = self
        }

        if (self.name == "Invalid Disk") {
            diskUtility.getNameForDisk(self) { (returnedName) in
                self.name = returnedName
                self.checkIfContainsInstaller()
                if let action = self.updatedAction {
                    action.action()
                }
                self.disk?.mountedDisk = self
            }
        }

        self.disk = existingDisk
    }


    public func checkIfContainsInstaller(shouldUpdate: Bool = false) {
        if((self.name.contains("Install OS X") || self.name.contains("Install macOS")) == true && self.containsInstaller == false) {
            let potentialInstaller = Installer(mountedDisk: self)
            if(potentialInstaller.isValid) {
                self.disk?.diskType = .dmg
                self.installer = potentialInstaller
                self.containsInstaller = true
            }
        } else if(self.containsInstaller == true) {
            self.containsInstaller = false
        }

        if(shouldUpdate) {
            self.disk?.updateMountedDisk(mountedDisk: self)
        }
    }

    public func eject() {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eject", self.devEntry]) { (ejectOutput) in
            print(ejectOutput ?? "No output")
            if let parentDisk = self.disk {
                parentDisk.eject()
            }
        }
    }

    private func getNameFromDiskUtil(returnCompletion: @escaping (String) -> ()) {
        DispatchQueue.main.async {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", self.devEntry]) { (diskUtilInfo) in
                var name = self.name
                if let volumeName = diskUtilInfo!.matches("Volume Name: *.*").first {
                    name = volumeName.replacingOccurrences(of: "Volume Name: *", with: "", options: .regularExpression)
                }
                returnCompletion(name)
            }
        }
    }
}
