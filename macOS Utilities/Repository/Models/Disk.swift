//
//  Disk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

struct Disk: Item, Codable {
    var content: String? = nil
    var deviceIdentifier: String
    var regularPartitions: [Partition]?
    var apfsPartitions: [Partition]?
    var size: Int
    var id: String {
        return String("\(deviceIdentifier)-\(size)-\(content ?? "None")").md5Value
    }

    var isAPFS: Bool {
        return regularPartitions == nil
    }

    var containsInstaller: Bool {
        return getInstaller() != nil
    }

    var installer: Installer {
        return self.getInstaller()!
    }

    private func getInstaller() -> Installer? {
        if let installerPartition = self.partitions.first(where: { $0.containsInstaller == true }) {
            return Installer.init(partition: installerPartition)
        }
        return nil
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
        return self.partitions.first { Units(bytes: $0.size).gigabytes > 120.0 && $0.isMounted }
    }
    
    private enum CodingKeys: String, CodingKey {
        case content = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case regularPartitions = "Partitions"
        case apfsPartitions = "APFSVolumes"
        case size = "Size"
    }

    func addToRepo() {
        print(self)
    }

    var description: String {
        return "Disk: \n\t Size: \(self.size)kb\n\t Content: \(self.content ?? "None")\n\t Device Identifier: \(self.deviceIdentifier) \n\t Partitions: \(self.partitions)\n"
    }

    static func == (lhs: Disk, rhs: Disk) -> Bool {
        // && lhs.partitions == rhs.partitions
        return lhs.content == rhs.content && lhs.deviceIdentifier == rhs.deviceIdentifier && lhs.size == rhs.size
    }
}
