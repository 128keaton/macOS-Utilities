//
//  DiskInfo.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct DiskInfo: Codable, CustomStringConvertible {
    var isRemovable: Bool
    var isInternal: Bool
    var registryEntryName: String

    var solidState: Bool? = nil

    var isSolidState: Bool {
        return solidState ?? false
    }

    var potentialFusionDriveHalve: Bool {
        return !isRemovable && isInternal && !isContainer
    }

    var isContainer: Bool {
        return registryEntryName != "AppleAPFSMedia"
    }

    var description: String {
        return "Removable: \(isRemovable), Internal: \(isInternal), Solid State: \(isSolidState)"
    }

    private enum CodingKeys: String, CodingKey {
        case isRemovable = "Removable"
        case isInternal = "Internal"
        case solidState = "SolidState"
        case registryEntryName = "IORegistryEntryName"
    }
}

