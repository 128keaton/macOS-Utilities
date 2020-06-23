//
//  DisplayItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct DisplayItem: ConcreteItemType {
    typealias ItemType = DisplayItem
    
    static var isNested: Bool = false
    var dataType: SPDataType = .display

    var graphicsCardModel: String
    var graphicsCardVRAM: String?
    var graphicsCardVRAMShared: String?

    private var _metalFamily: String?

    var isMetalCompatible: Bool {
        if let metalFamily = self._metalFamily {
            return metalFamily.contains("spdisplays_metalfeaturesetfamily")
        }

        return false
    }

    var description: String {
        return "\(graphicsCardModel): \(graphicsCardVRAM ?? graphicsCardVRAMShared ?? "No VRAM") Metal: \(self.isMetalCompatible ? "Yes" : "No")"
    }

    enum CodingKeys: String, CodingKey {
        case graphicsCardModel = "sppci_model"
        case graphicsCardVRAM = "spdisplays_vram"
        case graphicsCardVRAMShared = "spdisplays_vram_shared"
        case _metalFamily = "spdisplays_metal"
    }
}
