//
//  HDIUtilOutput.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class HDIUtilOutput: Decodable {
    var systemEntities: [DiskImage]
    
    init() {
        self.systemEntities = []
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.systemEntities = try values.decode([DiskImage].self, forKey: .systemEntities)
    }
    
    private enum CodingKeys: String, CodingKey {
        case systemEntities = "system-entities"
    }
}
