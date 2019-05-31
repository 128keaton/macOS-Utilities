//
//  HardwareItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class HardwareItem: ItemType {
    static var isNested: Bool = false
    var dataType: SPDataType = .display
    
    var physicalMemory: String
    var machineName: String
    var machineModel: String
    var cpuType: String
    var cpuCores: Int
    var serialNumber: String
    var physicalProcessorCount: Int
    var l2CacheSize: String
    var l3CacheSize: String
    
    var description: String {
        return "\(machineName): \(machineModel) - \(physicalMemory) - \(physicalProcessorCount)x \(cpuType) - \(cpuCores) Cores - \(serialNumber)"
    }
    
    var doubleMemory: Double {
        if let _doubleMemory = Double(physicalMemory.filter("01234567890.".contains)) {
            return _doubleMemory
        }
        
        return 0.0
    }
    
    required init(from decoder: Decoder)throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.physicalMemory = try container.decode(String.self, forKey: .physicalMemory)
        self.machineName = try container.decode(String.self, forKey: .machineName)
        self.machineModel = try container.decode(String.self, forKey: .machineModel)
        self.cpuType = try container.decode(String.self, forKey: .cpuType)
        self.cpuCores = try container.decode(Int.self, forKey: .cpuCores)
        self.serialNumber = try container.decode(String.self, forKey: .serialNumber)
        self.physicalProcessorCount = try container.decode(Int.self, forKey: .physicalProcessorCount)
        self.l2CacheSize = try container.decode(String.self, forKey: .l2CacheSize)
        self.l3CacheSize = try container.decode(String.self, forKey: .l3CacheSize)
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
