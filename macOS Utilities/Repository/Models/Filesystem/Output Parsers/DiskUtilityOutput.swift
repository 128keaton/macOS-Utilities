//
//  DiskUtilityOutput.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class DiskUtilOutput: Decodable {
    var allDisks: [String]?
    var allDisksAndPartitions: [Disk]?
    var volumesFromDisks: [String]?
    var wholeDisks: [String]?

    init() {
        self.allDisks = []
        self.allDisksAndPartitions = []
        self.volumesFromDisks = []
        self.wholeDisks = []
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.allDisks = try values.decode([String].self, forKey: .allDisks)
        self.allDisksAndPartitions = try values.decode([Disk].self, forKey: .allDisksAndPartitions)
        self.volumesFromDisks = try values.decode([String].self, forKey: .volumesFromDisks)
        self.wholeDisks = try values.decode([String].self, forKey: .wholeDisks)
    }

    private enum CodingKeys: String, CodingKey {
        case allDisks = "AllDisks"
        case allDisksAndPartitions = "AllDisksAndPartitions"
        case volumesFromDisks = "VolumesFromDisks"
        case wholeDisks = "WholeDisks"
    }
}
