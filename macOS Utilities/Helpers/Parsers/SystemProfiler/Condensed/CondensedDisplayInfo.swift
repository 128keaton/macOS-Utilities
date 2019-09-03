//
//  CondensedDisplayInfo.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedDisplayItem: Encodable {
    var graphicsCardName: String
    var graphicsCardVRAM: String

    init(from displayItem: DisplayItem) {
        graphicsCardName = displayItem.graphicsCardModel

        if let vram = displayItem.graphicsCardVRAM {
            graphicsCardVRAM = vram
        } else {
            graphicsCardVRAM = displayItem.graphicsCardVRAMShared!
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case graphicsCardName = "name"
        case graphicsCardVRAM = "vram"
    }
}
