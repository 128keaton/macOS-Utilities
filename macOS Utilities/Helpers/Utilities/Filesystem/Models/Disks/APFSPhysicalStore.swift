//
//  APFSPhysicalStore.swift
//  Shredder
//
//  Created by Keaton Burleson on 6/24/20.
//  Copyright © 2020 Pro Warehouse. All rights reserved.
//

import Foundation

// MARK: - APFSPhysicalStore
struct APFSPhysicalStore: Codable, CustomStringConvertible {
    let deviceIdentifier: String

    var description: String {
        return "APFSPhysicalStore - [Device Identifier: \(self.deviceIdentifier)]"
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceIdentifier = "DeviceIdentifier"
    }
}
