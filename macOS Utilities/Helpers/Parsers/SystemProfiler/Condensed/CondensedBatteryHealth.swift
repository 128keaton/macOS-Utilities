//
//  CondensedBatteryHealth.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedBatteryHealth: Encodable {
    var cycleCount: Int
    var healthStatus: String
    
    init(from batteryHealthInfo: BatteryHealthInfo) {
        cycleCount = batteryHealthInfo.cycleCount
        healthStatus = batteryHealthInfo.healthStatus
    }
    
    enum CodingKeys: String, CodingKey {
        case cycleCount = "cycles"
        case healthStatus
    }
}
