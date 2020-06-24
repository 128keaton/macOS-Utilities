//
//  BatteryItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct BatteryItem: ConcreteItemType, Codable {
    typealias ItemType = BatteryItem

    var dataType: SPDataType  = .power

    static var isNested: Bool = false
    
    private var _installed: String
    
    var installed: Bool {
        get {
            return _installed == "TRUE"
        }
        set {
            self._installed = newValue ? "TRUE" : "FALSE"
        }
    }
    
    var description: String {
        return "Battery: \(installed)"
    }
    
    var healthInfo: BatteryHealthInfo?
    var chargeInfo: BatteryChargeInfo?
    
    enum CodingKeys: String, CodingKey {
        case chargeInfo = "sppower_battery_charge_info"
        case healthInfo = "sppower_battery_health_info"
        case _installed = "sppower_battery_installed"
    }
}

struct BatteryHealthInfo: Codable{
    var cycleCount: Int
    var healthStatus: String
    
    enum CodingKeys: String, CodingKey {
        case cycleCount = "sppower_battery_cycle_count"
        case healthStatus = "sppower_battery_health"
    }
}

struct BatteryChargeInfo: Codable{
    var currentCapacity: Int
    var maxCapacity: Int
    
    private var _fullyCharged: String
    private var _isCharging: String
    
    var fullyCharged: Bool {
        return _fullyCharged == "TRUE"
    }
    
    var isCharging: Bool {
        return _isCharging == "TRUE"
    }
    
    enum CodingKeys: String, CodingKey {
        case currentCapacity = "sppower_battery_current_capacity"
        case maxCapacity = "sppower_battery_max_capacity"
        case _fullyCharged = "sppower_battery_fully_charged"
        case _isCharging = "sppower_battery_is_charging"
    }
}
