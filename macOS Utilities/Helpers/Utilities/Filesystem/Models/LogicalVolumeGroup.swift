//
//  LogicalVolumeGroup.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class LogicalVolumeGroup: FileSystemItem, Decodable {
    var itemType: FileSystemItemType = .logicalVolumeGroup
    var role: String
    var containerUUID: String
    
    var description: String {
        return "CoreStorageLogicalVolumeGroup: \(role) - \(containerUUID)"
    }
    
    var id: String {
        return containerUUID
    }
    
    private enum CodingKeys: String, CodingKey {
        case role = "CoreStorageRole"
        case containerUUID = "CoreStorageUUID"
    }
}
