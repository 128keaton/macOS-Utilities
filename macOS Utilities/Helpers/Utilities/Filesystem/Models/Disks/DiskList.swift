//
//  DiskList.swift
//  Shredder
//
//  Created by Keaton Burleson on 6/24/20.
//  Copyright © 2020 Pro Warehouse. All rights reserved.
//

import Foundation

// MARK: - ListDisks
struct DiskList: Codable, CustomStringConvertible {
    let allDisksAndPartitions: [DisksAndPartitions]
    let volumesFromDisks, allDisks, wholeDisks: [String]

    var description: String {
        var base = "DiskList: \n"
        
        base += String(describing: allDisksAndPartitions)
        
        return base
    }
    
    enum CodingKeys: String, CodingKey {
        case allDisksAndPartitions = "AllDisksAndPartitions"
        case volumesFromDisks = "VolumesFromDisks"
        case allDisks = "AllDisks"
        case wholeDisks = "WholeDisks"
    }
}
