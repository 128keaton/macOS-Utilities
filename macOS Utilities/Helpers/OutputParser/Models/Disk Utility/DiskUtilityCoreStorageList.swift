//
//  DiskUtilityCoreStorageList.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class DiskUtilityCoreStorageList: RawOutputType, Decodable, CustomStringConvertible {
    var toolType: OutputToolType = .diskUtility
    var type: OutputType = .coreStorageList
    
    var logicalVolumeGroups: [LogicalVolumeGroup]
    
    var description: String {
        return "CoreStorageList: \(logicalVolumeGroups)"
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.logicalVolumeGroups = try values.decode([LogicalVolumeGroup].self, forKey: .logicalVolumeGroups)
    }

    private enum CodingKeys: String, CodingKey {
        case logicalVolumeGroups = "CoreStorageLogicalVolumeGroups"
    }
}
