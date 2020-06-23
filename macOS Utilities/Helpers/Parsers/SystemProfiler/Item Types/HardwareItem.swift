//
//  HardwareItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class HardwareItem: ConcreteItemType {
    typealias ItemType = HardwareItem
    
    static var isNested: Bool = false
    var dataType: SPDataType = .display

    var physicalMemory: String?
    var machineName: String?
    var machineModel: String?
    var cpuType: String?
    var cpuCores: Int?
    var serialNumber: String?
    var physicalProcessorCount: Int?
    var l2CacheSize: String?
    var l3CacheSize: String?

    var description: String {
        return "\(machineName ?? "No machine name"): \(machineModel ?? "No machine model") - \(physicalMemory ?? "No memory") - \(physicalProcessorCount ?? 1)x \(cpuType ?? "Unknown") - \(cpuCores ?? 1) Cores - \(serialNumber ?? "Unknown")"
    }

    var doubleMemory: Double {
        if let validPhysicalMemory = physicalMemory,
            let _doubleMemory = Double(validPhysicalMemory.filter("01234567890.".contains)) {

            return _doubleMemory
        }

        return 0.0
    }

    required init(from decoder: Decoder)throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.physicalMemory = try container.decodeIfPresent(String.self, forKey: .physicalMemory)
        self.machineName = try container.decodeIfPresent(String.self, forKey: .machineName)
        self.machineModel = try container.decodeIfPresent(String.self, forKey: .machineModel)
        self.cpuType = try container.decodeIfPresent(String.self, forKey: .cpuType)
        self.cpuCores = try container.decodeIfPresent(Int.self, forKey: .cpuCores)
        self.serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        self.physicalProcessorCount = try container.decodeIfPresent(Int.self, forKey: .physicalProcessorCount)
        self.l2CacheSize = try container.decodeIfPresent(String.self, forKey: .l2CacheSize)
        self.l3CacheSize = try container.decodeIfPresent(String.self, forKey: .l3CacheSize)
    }

    private func getDetailedCPUInfo() -> String? {
        let launchPath = "/usr/sbin/sysctl"
        if !FileManager.default.isExecutableFile(atPath: launchPath) {
            return nil
        }

        let infoTask = Process()
        let standardPipe = Pipe()

        infoTask.launchPath = launchPath
        infoTask.arguments = ["-n", "machdep.cpu.brand_string"]
        infoTask.standardOutput = standardPipe
        infoTask.waitUntilExit()

        infoTask.launch()

        let detailedCPUInfoData = standardPipe.fileHandleForReading.readDataToEndOfFile()

        if detailedCPUInfoData.count > 0,
            let detailedCPUInfo = String(data: detailedCPUInfoData, encoding: .utf8) {
            return detailedCPUInfo
        }

        return nil
    }

    func updateCPUInfo(_ newCPUInfo: String) {
        self.cpuType = newCPUInfo
    }

    enum CodingKeys: String, CodingKey {
        case physicalMemory = "physical_memory"
        case machineName = "machine_name"
        case machineModel = "machine_model"
        case cpuType = "cpu_type"
        case cpuCores = "number_processors"
        case serialNumber = "serial_number"
        case physicalProcessorCount = "packages"
        case l2CacheSize = "l2_cache_core"
        case l3CacheSize = "l3_cache"
    }
}
