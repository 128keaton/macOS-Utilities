//
//  CoreStorage.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class CoreStorage: Codable, CustomStringConvertible{
    var role: String
    var volumeUUID: String
    var description: String {
        return "CoreStorage: \(role) - \(volumeUUID)"
    }
    
    private enum CodingKeys: String, CodingKey {
        case role = "CoreStorageRole"
        case volumeUUID = "CoreStorageUUID"
    }
}
