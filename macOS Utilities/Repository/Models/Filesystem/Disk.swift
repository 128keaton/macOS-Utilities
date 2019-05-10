//
//  Disk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class Disk: FileSystemItem, Codable {
    var rawContent: String? = nil
    var deviceIdentifier: String
    var regularPartitions: [Partition]?
    var apfsPartitions: [Partition]?
    var rawSize: Int64
    var isFake: Bool = false
    var info: DiskInfo? = nil

    var size: Units {
        return Units(bytes: self.rawSize)
    }
    var content: String {
        return self.rawContent ?? "None"
    }

    var itemType: FileSystemItemType {
        return .disk
    }

    var id: String {
        return String("\(deviceIdentifier)-\(size)-\(content)").md5Value
    }

    var isAPFS: Bool {
        return regularPartitions == nil
    }

    var canErase: Bool {
        var userConfirmedErase = true
        if let mainWindow = NSApplication.shared.mainWindow,
            let contentViewController = mainWindow.contentViewController {
            userConfirmedErase = contentViewController.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(self.deviceIdentifier)? This will make all the data on \(self.deviceIdentifier) unrecoverable.")
        }

        return userConfirmedErase
    }

    var partitions: [Partition] {
        var allPartitions: [Partition] = []

        if let _regularPartitions = self.regularPartitions {
            allPartitions.append(contentsOf: _regularPartitions)
        }

        if let _apfsPartitions = self.apfsPartitions {
            allPartitions.append(contentsOf: _apfsPartitions)
        }

        return allPartitions
    }

    var installablePartition: Partition? {
        return self.partitions.first { $0.installable == true }
    }

    var volumeName: String {
        if let mainPartition = self.installablePartition {
            return mainPartition.volumeName
        }
        return "None"
    }

    private enum CodingKeys: String, CodingKey {
        case rawContent = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case regularPartitions = "Partitions"
        case apfsPartitions = "APFSVolumes"
        case rawSize = "Size"
    }

    static func copy(_ aDisk: Disk) throws -> Disk {
        let data = try PropertyListEncoder().encode(aDisk)
        let copy = try PropertyListDecoder().decode(Disk.self, from: data)
        return copy
    }

    required init(from decoder: Decoder) throws{
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.rawContent = try container.decodeIfPresent(String.self, forKey: .rawContent)
        self.deviceIdentifier = try container.decode(String.self, forKey: .deviceIdentifier)
        self.regularPartitions = try container.decodeIfPresent([Partition].self, forKey: .regularPartitions)
        self.apfsPartitions = try container.decodeIfPresent([Partition].self, forKey: .apfsPartitions)
        self.rawSize = try container.decode(Int64.self, forKey: .rawSize)
        
        DiskUtility.shared.getDiskInfo(self) { (diskInfo) in
            if diskInfo != nil {
                self.info = diskInfo
            }
        }
        
        self.partitions.forEach {
            $0.scanForInstaller()
        }
    }
    
    init(rawContent: String? = nil, deviceIdentifier: String, regularPartitions: [Partition]?, apfsPartitions: [Partition]?, rawSize: Int64, isFake: Bool = false, info: DiskInfo? = nil){
        self.rawContent = rawContent
        self.deviceIdentifier = deviceIdentifier
        self.regularPartitions = regularPartitions
        self.apfsPartitions = apfsPartitions
        self.rawSize = rawSize
        self.isFake = isFake
        self.info = info
    }
    
    init(existingDisk: Disk, regularPartitions passedPartitions: [Partition]) {
        self.rawContent = existingDisk.rawContent
        self.deviceIdentifier = existingDisk.deviceIdentifier
        self.regularPartitions = passedPartitions
        self.apfsPartitions = nil
        self.rawSize = existingDisk.rawSize
        self.isFake = existingDisk.isFake
        self.info = existingDisk.info
    }
    
    init(existingDisk: Disk, apfsPartitions passedPartitions: [Partition]) {
        self.rawContent = existingDisk.rawContent
        self.deviceIdentifier = existingDisk.deviceIdentifier
        self.apfsPartitions = passedPartitions
        self.regularPartitions = nil
        self.rawSize = existingDisk.rawSize
        self.isFake = existingDisk.isFake
        self.info = existingDisk.info
    }
    
    static func copy(_ aDisk: Disk, regularPartitions partitions: [Partition]) throws -> Disk {
        let copy = Disk(existingDisk: aDisk, regularPartitions: partitions)
        return copy
    }

    static func copy(_ aDisk: Disk, apfsPartitions partitions: [Partition]) throws -> Disk {
        let copy = Disk(existingDisk: aDisk, apfsPartitions: partitions)
        return copy
    }

    public func erase(newName: String? = nil, forInstaller: Installer? = nil, returnCompletion: @escaping (Bool, String?) -> ()) {
        DiskUtility.shared.erase(self, newName: newName, forInstaller: forInstaller) { (didComplete, newDiskName) in
            returnCompletion(didComplete, newDiskName)
        }
    }

    var description: String {
        return "Disk: \n\t Size: \(self.size)\n\t Content: \(self.content)\n\t Device Identifier: \(self.deviceIdentifier) \n\t Partitions: \(self.partitions) \n\t Has Info: \(self.info == nil ? "no" : "yes") \n\t Installable Partition: \(String(describing: self.installablePartition))\n"
    }

    static func == (lhs: Disk, rhs: Disk) -> Bool {
        // && lhs.partitions == rhs.partitions
        return lhs.content == rhs.content && lhs.deviceIdentifier == rhs.deviceIdentifier && lhs.size == rhs.size
    }
}
