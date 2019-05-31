//
//  AudioItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct AudioItem: ItemType {
    static var isNested: Bool = true
    var dataType: SPDataType = .audio
    
    var name: String
    var manufacturer: String
    
    var description: String {
        return "\(name): \(manufacturer)"
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "_name"
        case manufacturer = "coreaudio_device_manufacturer"
    }
}

class NestedAudioItem: NestedItemType {
    var items: [Decodable] = []
    var name: String
    
    var description: String {
        return "\(name): \(items)"
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "_name"
        case items = "_items"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let audioItems = try container.decodeIfPresent([AudioItem].self, forKey: .items)
        self.name = try container.decode(String.self, forKey: .name)
        
        if audioItems != nil {
            self.items = audioItems! as [Decodable]
        }
    }
}


