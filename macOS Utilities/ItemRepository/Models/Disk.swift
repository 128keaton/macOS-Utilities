//
//  Disk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

struct Disk: Item {
    typealias ItemType = Disk

    var deviceIdentifier: String = "Invalid"
    var content: String = "Invalid"
    var size: Double = 0.0
    var volumes = [Volume]()
    var id: String = String.random(12).md5Value
    var measurementUnit: String = "GB"

    var isInstallable: Bool {
        return (measurementUnit == "GB" ? size > 150.0: true)
    }

    var description: String {
        return "Disk: \n\t Device Identifier: \(self.deviceIdentifier) \n\t Content: \(self.content)  \n\t   Installable: \(self.isInstallable) \n\t Size: \(self.size) \(self.measurementUnit) \n\t   Volumes: \(self.volumes) \n "
    }

    private init() {

    }

    init(diskDictionary: NSDictionary) {
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

        self.addToRepo()
    }

    init(diskImageDictionary: NSDictionary) {
        self.init()
        if let systemEntities = diskImageDictionary["system-entities"] as? [NSDictionary] {
            if let diskMetadata = (systemEntities.first { ($0["potentially-mountable"] as! Bool) == false }) {
                if let deviceIdentifier = diskMetadata["dev-entry"] as? String {
                    self.deviceIdentifier = deviceIdentifier
                }

                if let content = diskMetadata["content-hint"] as? String {
                    self.content = content
                }
            }

            if let volumeMetadata = (systemEntities.first { ($0["potentially-mountable"] as! Bool) == true }) {
                volumes.append(Volume(hdiutilVolumeDictionary: volumeMetadata, disk: self))
            }
        }

        self.addToRepo()
    }

    init(deviceIdentifier: String = "NFS", content: String = "NFS", mountPoint: String) {
        self.init()

        self.deviceIdentifier = deviceIdentifier
        self.content = content
        self.volumes = [Volume(mountPoint: mountPoint, content: content, disk: self)]
        self.addToRepo()
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
