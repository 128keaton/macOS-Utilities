//
//  Disk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class Disk: Item {
    typealias ItemType = Disk

    var deviceIdentifier: String = "Invalid"
    var content: String = "Invalid"
    var size: Double = 0.0
    var volumes = [Volume]()
    var id: String = String.random(12).md5Value
    var measurementUnit: String = "GB"
    var isFakeDisk: Bool = false
    var isAPFS: Bool = false
    var isFusion: Bool = false
    var containerIdentifier: String? = nil

    var isInstallable: Bool {
        return (measurementUnit == "GB" ? size > 150.0: true) || isFakeDisk == true
    }


    var description: String {
        return isFakeDisk ? "FakeDisk (created by application)" : "Disk: \n\t Device Identifier: \(self.deviceIdentifier) \n\t Content: \(self.content)  \n\t   Installable: \(self.isInstallable) \n\t Size: \(self.size) \(self.measurementUnit) \n\t   Volumes: \(self.volumes) \n "
    }

    private init() {

    }

    convenience init(diskDictionary: NSDictionary) {
        self.init()
        if let deviceIdentifier = diskDictionary["DeviceIdentifier"] as? String {
            self.deviceIdentifier = deviceIdentifier
        }

        if let content = diskDictionary["Content"] as? String {
            self.content = content
        }

        if let size = diskDictionary["Size"] as? Int {
            self.size = (Double(size) / 1073741824.0).rounded()
            if(self.size > 1000.0) {
                self.measurementUnit = "TB"
                self.size = self.size / 1000.0
            }
        }

        if let unparsedVolumes = diskDictionary["APFSVolumes"] as? [NSDictionary] {
            self.volumes = unparsedVolumes.map { Volume($0, disk: self) }
        } else if let unparsedPartitions = diskDictionary["Partitions"] as? [NSDictionary] {
            self.volumes = unparsedPartitions.map { Volume($0, disk: self) }
        }

        self.checkIfAPFS()

        self.addToRepo()
    }

    convenience init(diskImageDictionary: NSDictionary) {
        self.init()
        if let systemEntities = diskImageDictionary["system-entities"] as? [NSDictionary] {
            if let volumeMetadata = (systemEntities.first { ($0["potentially-mountable"] as! Bool) == true && ($0["content-hint"] as! String) != "EFI" }) {
                volumes.append(Volume(hdiutilVolumeDictionary: volumeMetadata, disk: self))

                if let devEntry = volumeMetadata["dev-entry"] as? String {
                    self.deviceIdentifier = devEntry

                    if let volumeKind = volumeMetadata["volume-kind"] as? String {
                        if (volumeKind == "apfs") {
                            self.checkIfAPFS()
                        }
                    }
                }
            }
        }

        self.addToRepo()
    }

    convenience init(deviceIdentifier: String = "NFS", content: String = "NFS", mountPoint: String) {
        self.init()

        self.deviceIdentifier = deviceIdentifier
        self.content = content
        self.volumes = [Volume(mountPoint: mountPoint, content: content, disk: self)]

        self.checkIfAPFS()

        self.addToRepo()
    }

    convenience init(isFakeDisk: Bool = true) {
        self.init()

        if !isFakeDisk {
            DDLogError("FakeDisk initializer called with isFakeDisk == false.. This initializer (for right now) should only be called with isFakeDisk == true")
            fatalError()
        }

        self.isFakeDisk = true
        self.deviceIdentifier = "/dev/null"
        self.content = "Utilities_Fake_Disk"
        self.size = 99
        self.measurementUnit = "TB"

        self.volumes = [Volume(disk: self)]
        self.addToRepo()
    }

    public func checkIfAPFS() {
        DiskUtility.shared.diskIsAPFS(self) { (apfsData) in
            if let apfsDictionary = apfsData {
                self.isAPFS = true
                if let containers = apfsDictionary["Containers"] as? [NSDictionary] {
                    for container in containers {

                        if let isFusion = container["Fusion"] as? Bool {
                            self.isFusion = isFusion
                        }

                        if let designatedPhysicalStore = container["DesignatedPhysicalStore"] as? String {
                            self.containerIdentifier = self.deviceIdentifier
                            self.deviceIdentifier = "/dev/\(designatedPhysicalStore)"
                        }

                        if let apfsVolumes = container["Volumes"] as? [NSDictionary] {
                            for apfsVolume in apfsVolumes {
                                if let apfsVolumeName = apfsVolume["Name"] as? String {
                                    if let matchedVolume = (self.volumes.first { $0.volumeName == apfsVolumeName }) {
                                        matchedVolume.deviceIdentifier = self.deviceIdentifier
                                        matchedVolume.updateWithAPFSData([container, apfsVolume])
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }
    }

    func getMainVolume() -> Volume? {
        return self.volumes.max { a, b in a.size < b.size }
    }

    func addToRepo() {
        ItemRepository.shared.addToRepository(newDisk: self)
    }

    func update() {
        ItemRepository.shared.updateDisk(self)
    }

    static func == (lhs: Disk, rhs: Disk) -> Bool {
        return lhs.id == rhs.id && rhs.getMainVolume() == lhs.getMainVolume()
    }
}
