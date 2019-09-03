//
//  hdiutilMount.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct hdiutilMount: RawOutputType, Decodable {
    var toolType: OutputToolType = .hdiutil
    var type: OutputType = .mount
    var retryType: RawOutputType? = nil
    
    var diskImages: [DiskImage]
    
    var mountableDiskImage: DiskImage? {
        return diskImages.first { $0.isMountable }
    }

    var description: String {
        return "hdiutil mount: \n System Entities: \n\t \(self.diskImages.map { $0.description })"
    }

    private enum CodingKeys: String, CodingKey {
        case diskImages = "system-entities"
    }
}
