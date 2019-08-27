//
//  DiskUtilList.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class DiskUtilityList: RawOutputType, CustomStringConvertible, Codable {
    var toolType: OutputToolType = .diskUtility
    var type: OutputType = .list
    
    var allDisks: [String]?
    var allDisksAndPartitions: [Disk]?
    var volumesFromDisks: [String]?
    var wholeDisks: [String]?
    var disks: [Disk] {
        if let _allDisksAndPartitions = self.allDisksAndPartitions {
            return _allDisksAndPartitions
        }
        return []
    }
    
    var description: String {
        var descriptionString = "DiskUtilityList"
        
        if let _allDisks = self.allDisks {
            descriptionString = "\(descriptionString) AllDisks: \(_allDisks.joined(separator: ", "))"
        }
        
        if let _allDisksAndPartitions = self.allDisksAndPartitions {
            descriptionString = "\(descriptionString) AllDisksAndPartitions: \(_allDisksAndPartitions)"
        }
        
        if let _volumesFromDisks = self.volumesFromDisks {
            descriptionString = "\(descriptionString) VolumesFromDisks: \(_volumesFromDisks.joined(separator: ", "))"
        }
        
        if let _wholeDisks = self.wholeDisks {
            descriptionString = "\(descriptionString) WholeDisks: \(_wholeDisks.joined(separator: ", "))"
        }
        
        return descriptionString
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
