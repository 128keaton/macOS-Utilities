//
//  DiskUtilityInfo.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class DiskUtilityInfo: RawOutputType, CustomStringConvertible, Codable {
    var toolType: OutputToolType = .diskUtility
    var type: OutputType = .info
    
    var isRemovable: Bool
    var isInternal: Bool
    var virtualOrPhysical: String
    var solidState: Bool? = nil

    var isSolidState: Bool {
        return solidState ?? false
    }

    var potentialFusionDriveHalve: Bool {
        return !isRemovable && isInternal && isPhysical
    }

    var isPhysical: Bool {
        return virtualOrPhysical == "Physical"
    }

    var isVirtual: Bool {
        return virtualOrPhysical == "Virtual"
    }

    var description: String {
        return "Removable: \(isRemovable), Internal: \(isInternal), Solid State: \(isSolidState)"
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.isRemovable = try values.decode(Bool.self, forKey: .isRemovable)
        self.isInternal = try values.decode(Bool.self, forKey: .isInternal)
        self.virtualOrPhysical = try values.decode(String.self, forKey: .virtualOrPhysical)
        self.solidState = try values.decodeIfPresent(Bool.self, forKey: .solidState)
    }

    private enum CodingKeys: String, CodingKey {
        case isRemovable = "Removable"
        case isInternal = "Internal"
        case solidState = "SolidState"
        case virtualOrPhysical = "VirtualOrPhysical"
    }
}
