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
    var mountPoint: String = "/dev/null"
    var name: String = "Invalid Disk"
    var size: Double = 0.0
    var measurementUnit: String = "GB"
    var isInternal: Bool = true
    var disk: Disk? = nil
    var containsInstaller: Bool = false {
        didSet {
            DiskRepository.shared.installersDidUpdate()
        }
    }

    var installer: Installer? = nil

    var uniqueMountID: String {
        guard let data = self.name.data(using: String.Encoding.utf8) else { return self.name }

        let hash = data.withUnsafeBytes { (bytes: UnsafePointer<Data>) -> [UInt8] in
            var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            CC_SHA1(bytes, CC_LONG(data.count), &hash)
            return hash
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    var isValid: Bool {
        return self.mountPoint != "/dev/null" && self.name != "Not applicable (no file system)"
    }
    var isInstallable: Bool {
        return (self.size > 150.0 || self.measurementUnit == "TB") && isValid
    }

    var description: String {
        let baseString = "MountedDisk: \n\t Name: \(self.name) \n\t Size: \(self.size) \(self.measurementUnit) \n\t Valid: \(self.isValid) \n\t Contains Installer: \(self.containsInstaller) \n\t Mount Point: \(self.mountPoint) \n\t Internal: \(self.isInternal)\n"
        if(containsInstaller == true) {
            return "\(baseString) \t\t \(self.installer!)"
        }

        return baseString
    }

    init(disk: Disk, matchedDiskOutput: String) {
        if let matchedSize = matchedDiskOutput.matches("([0-9]+( |.[0-9]+ )(GB|TB))", stripR: ["\\*", "\\+"]).first {
            if(matchedSize.contains("TB")) {
                self.measurementUnit = "TB"
            }

            self.size = matchedSize.doubleValue
        }

        if let matchedMountPoint = matchedDiskOutput.matches("disk([0-9]*)s.").first {
            self.mountPoint = "/dev/\(matchedMountPoint)"
        }

        self.disk = disk
        getNameFromDiskUtil { (name) in
            self.name = name
            self.checkIfContainsInstaller()
        }
    }

    public func checkIfContainsInstaller() {
        DispatchQueue.main.async {
            if(self.name.contains("Install OS X") || self.name.contains("Install macOS")) {
                let potentialInstaller = Installer(mountedDisk: self)
                if(potentialInstaller.isValid) {
                    self.disk?.diskType = .dmg
                    self.installer = potentialInstaller
                    self.containsInstaller = true
                    self.disk?.updateMountedDisk(mountedDisk: self)
                    return
                }
            }
            self.disk?.updateMountedDisk(mountedDisk: self)
            self.containsInstaller = false
        }
    }

    public func eject() {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eject", self.mountPoint]) { (ejectOutput) in
            print(ejectOutput ?? "No output")
            if let parentDisk = self.disk {
                parentDisk.mountedDisk = nil
            }
        }
    }

    private func getNameFromDiskUtil(returnCompletion: @escaping (String) -> ()) {
        DispatchQueue.main.async {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", self.mountPoint]) { (diskUtilInfo) in
                var name = self.name
                if let volumeName = diskUtilInfo!.matches("Volume Name: *.*").first {
                    name = volumeName.replacingOccurrences(of: "Volume Name: *", with: "", options: .regularExpression)
                }
                returnCompletion(name)
            }
        }
    }
}
