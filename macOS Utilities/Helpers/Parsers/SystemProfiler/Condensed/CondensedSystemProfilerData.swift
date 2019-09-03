//
//  CondensedSystemProfilerData.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedSystemProfilerData: Encodable {
    var hardware: CondensedHardwareInfo?
    var notes: String = String()
    
    enum CodingKeys: String, CodingKey {
        case hardware = "machineInfo"
        case notes = "testingNotes"
    }

    init(from allData: [[ItemType]], notes: String = "") {
        let mappedData = allData.compactMap { $0.first }

        print(mappedData)
        if let hardwareItem = (mappedData.first { $0.dataType == .hardware }) as? HardwareItem {
            self.hardware = CondensedHardwareInfo(from: hardwareItem)
            self.notes = notes
            
            if let powerItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .power }),
                let batteryItem = powerItems.first(where: { type(of: $0) == BatteryItem.self }) as? BatteryItem,
                let healthInfo = batteryItem.healthInfo {
                self.hardware!.batteryHealth = CondensedBatteryHealth(from: healthInfo)
            }

            if let displayItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .display }) as? [DisplayItem] {
                self.hardware!.graphicsCards = displayItems.map { CondensedDisplayItem(from: $0) }
            }

            if let serialATAItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .serialATA }) as? [SerialATAItem] {
                let storageItems = serialATAItems.filter { !$0.isDiscDrive }
                let discBurningItems = serialATAItems.filter { $0.isDiscDrive }


                self.hardware!.discDrives.append(contentsOf: discBurningItems.map { CondensedStorageItem(from: $0) })
                self.hardware!.storageDevices.append(contentsOf: storageItems.map { CondensedStorageItem(from: $0) })
            }

            if let NVMeItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .NVMe }) as? [NVMeItem] {
                self.hardware!.storageDevices.append(contentsOf: NVMeItems.map { CondensedStorageItem(from: $0) })
            }

            if let memoryItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .memory }) as? [MemoryItem] {
                self.hardware!.memory = memoryItems
            }
        }
    }
}
