//
//  CondensedSystemProfilerData.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedSystemProfilerData: Encodable {
    var model: String?
    var serialNumber: String?
    var processorInfo: String?
    var numberOfCores: Int?
    var numberOfProcessors: Int?
    var memory: [MemoryItem]?
    var configurationCode: String?
    var totalMemory: String?
    var l2CacheSize: String?
    var l3CacheSize: String?
    
    var storageDevices: [CondensedStorageItem]? = []
    var discDrives: [CondensedStorageItem]? = []
    var graphicsCards: [CondensedDisplayItem]?
    
    var batteryHealth: CondensedBatteryHealth?
    
    enum CodingKeys: String, CodingKey {
        case storageDevices, graphicsCards, discDrives, numberOfProcessors, serialNumber, model, numberOfCores, memory, l2CacheSize, l3CacheSize
        case batteryHealth = "battery"
        case processorInfo = "processor"
        case totalMemory = "totalMemory"
    }
    
    init(from allData: [[ItemType]]) {
        if let hardwareItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .hardware }) as? [HardwareItem],
            let hardwareItem = hardwareItems.first {
            
            processorInfo = hardwareItem.cpuType
            totalMemory = hardwareItem.physicalMemory
            serialNumber = hardwareItem.serialNumber
            numberOfProcessors = hardwareItem.physicalProcessorCount
            numberOfCores = hardwareItem.cpuCores
            model = hardwareItem.machineModel
            l3CacheSize = hardwareItem.l3CacheSize
            l2CacheSize = hardwareItem.l2CacheSize
        }
        
        if let powerItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .power }),
            let batteryItem = powerItems.first(where: { type(of: $0) == BatteryItem.self }) as? BatteryItem,
            let healthInfo = batteryItem.healthInfo {
            self.batteryHealth = CondensedBatteryHealth(from: healthInfo)
        }
        
        if let displayItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .display }) as? [DisplayItem] {
            self.graphicsCards = displayItems.map { CondensedDisplayItem(from: $0) }
        }
        
        if let serialATAItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .serialATA }) as? [SerialATAItem] {
            let storageItems = serialATAItems.filter { !$0.isDiscDrive }
            let discBurningItems = serialATAItems.filter { $0.isDiscDrive }
            
            self.storageDevices?.append(contentsOf: storageItems.map { CondensedStorageItem(from: $0) })
            self.discDrives?.append(contentsOf: discBurningItems.map { CondensedStorageItem(from: $0) })
        }
        
        if let NVMeItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .NVMe }) as? [NVMeItem] {
            self.storageDevices?.append(contentsOf: NVMeItems.map { CondensedStorageItem(from: $0) })
        }
        
        if let memoryItems = allData.first(where: { $0.first != nil && $0.first!.dataType == .memory }) as? [MemoryItem] {
            self.memory = memoryItems
        }
    }
}
