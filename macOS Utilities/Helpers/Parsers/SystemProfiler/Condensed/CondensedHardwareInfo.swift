//
//  CondensedHardwareInfo.swift
//  AVTest
//
//  Created by Keaton Burleson on 6/3/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct CondensedHardwareInfo: Encodable {
    var model: String?
    var serialNumber: String?
    var processorInfo: String?
    var numberOfCores: Int?
    var numberOfProcessors: Int?
    var totalMemory: String?
    var l2CacheSize: String?
    var l3CacheSize: String?

    var storageDevices: [CondensedStorageItem] = []
    var discDrives: [CondensedStorageItem] = []
    var graphicsCards: [CondensedDisplayItem] = []
    var memory: [MemoryItem] = []

    var batteryHealth: CondensedBatteryHealth?

    init(from hardwareItem: HardwareItem) {
        processorInfo = hardwareItem.cpuType
        totalMemory = hardwareItem.physicalMemory
        serialNumber = hardwareItem.serialNumber
        numberOfProcessors = hardwareItem.physicalProcessorCount
        numberOfCores = hardwareItem.cpuCores
        model = hardwareItem.machineModel
        l3CacheSize = hardwareItem.l3CacheSize
        l2CacheSize = hardwareItem.l2CacheSize
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(model, forKey: .model)
        try container.encode(serialNumber, forKey: .serialNumber)
        try container.encode(processorInfo, forKey: .processorInfo)
        try container.encode(numberOfCores, forKey: .numberOfCores)
        try container.encode(numberOfProcessors, forKey: .numberOfProcessors)
        try container.encode(totalMemory, forKey: .totalMemory)
        try container.encode(l2CacheSize, forKey: .l2CacheSize)
        try container.encode(l3CacheSize, forKey: .l3CacheSize)

        try container.encode(storageDevices, forKey: .storageDevices)
        try container.encode(discDrives, forKey: .discDrives)
        
        try container.encode(graphicsCards, forKey: .graphicsCards)
        try container.encode(memory, forKey: .memory)
        
        try container.encode(batteryHealth, forKey: .batteryHealth)
    }

    enum CodingKeys: String, CodingKey {
        case model, serialNumber, numberOfCores, numberOfProcessors, totalMemory, l2CacheSize, l3CacheSize, storageDevices, discDrives, memory, graphicsCards
        case processorInfo = "processor"
        case batteryHealth = "battery"
    }
}
