//
//  PowerItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class PowerItem: ConcreteItemType {
     typealias ItemType = PowerItem
    
    static var isNested: Bool = false
    var dataType: SPDataType = .power
    
    var name: String
    var battery: BatteryItem?
    
    
    var description: String {
        if let validBatteryItem = battery {
            return "\(name): \(validBatteryItem)"
        }
        return "No battery installed"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if name == "spbattery_information" {
            battery = try BatteryItem.init(from: decoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "_name"
        case battery
    }
}
