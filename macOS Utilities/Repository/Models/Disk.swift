//
//  Disk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class Disk: Item, Codable {
    var content: String
    var deviceIdentifier: String
    var partitions: [Partition]
    var size: Int
    var id: String {
        return String("\(deviceIdentifier)-\(size)-\(content)").md5Value
    }
    
    private enum CodingKeys: String, CodingKey {
        case content = "Content"
        case deviceIdentifier = "DeviceIdentifier"
        case partitions = "Partitions"
        case size = "Size"
    }

    func addToRepo() {
        print(self)
    }
    
    var description: String {
        return "Disk: \(content) \(deviceIdentifier) \(partitions) \(size)"
    }
    
    static func == (lhs: Disk, rhs: Disk) -> Bool {
        return lhs.content == rhs.content && lhs.deviceIdentifier == rhs.deviceIdentifier && lhs.partitions == rhs.partitions && lhs.size == rhs.size
    }
}
