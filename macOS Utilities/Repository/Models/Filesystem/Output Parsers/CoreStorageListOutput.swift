//
//  CoreStorageListOutput.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
class CoreStorageList: Codable, CustomStringConvertible{
    var volumes: [CoreStorage]
    var description: String {
        return "CoreStorageList: \(volumes)"
    }
    
    private enum CodingKeys: String, CodingKey {
        case volumes = "CoreStorageLogicalVolumeGroups"
    }
}
