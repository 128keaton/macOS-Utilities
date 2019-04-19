//
//  File.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class MachineInformation {
    // MARK: Configuration
    private class Config {
        var diskUtility: DiskUtility? = nil
        var deviceIdentifier: DeviceIdentifier? = nil
        var isConfigured: Bool = false
        var CPU: String? = nil
        var deviceInfo: DeviceInfo? = nil
        var serialNumber: String? = NSApplication.shared.getSerialNumber()
    }

    // MARK: Stored properties
    private var diskUtility: DiskUtility? = nil
    private var deviceIdentifier: DeviceIdentifier? = nil
    private var deviceInfo: DeviceInfo? = nil

    private (set) public var metalGPUs: [String] = []
    private (set) public var nonMetalGPUs: [String] = []
    private (set) public var CPU: String = String()

    static let shared = MachineInformation()
    private static let config = Config()

    // MARK: Initializers
    private init() {
        if let deviceInfo = MachineInformation.config.deviceInfo {
            self.deviceInfo = deviceInfo
        }
        
        if let CPU = MachineInformation.config.CPU {
            self.CPU = CPU
        }
    }

    // MARK: Functions
    static func setup(deviceIdentifier: DeviceIdentifier) {
        MachineInformation.config.deviceIdentifier = deviceIdentifier
        MachineInformation.config.diskUtility = DiskUtility.shared
        MachineInformation.config.isConfigured = true

        getCPUInfo()
        getDeviceInfo()
    }

    static func setup(diskUtility: DiskUtility) {
        if DeviceIdentifier.isConfigured {
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
        }

        MachineInformation.config.diskUtility = diskUtility
        MachineInformation.config.isConfigured = true

        getCPUInfo()
        getDeviceInfo()
    }

    static func setup(deviceIdentifier: DeviceIdentifier, diskUtility: DiskUtility) {
        MachineInformation.config.deviceIdentifier = deviceIdentifier
        MachineInformation.config.diskUtility = diskUtility
        MachineInformation.config.isConfigured = true

        getCPUInfo()
        getDeviceInfo()
    }

    static func setup(apiKey: String) {
        if DeviceIdentifier.isConfigured {
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
        } else {
            DeviceIdentifier.setup(authenticationToken: apiKey)
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
        }
        MachineInformation.config.diskUtility = DiskUtility.shared
        MachineInformation.config.isConfigured = true

        getCPUInfo()
        getDeviceInfo()
    }

    static func setup() {
        if DeviceIdentifier.isConfigured {
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
        }
        MachineInformation.config.diskUtility = DiskUtility.shared
        MachineInformation.config.isConfigured = true

        getCPUInfo()
        getDeviceInfo()
    }

    private static func getCPUInfo() {
        TaskHandler.createTask(command: "/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"]) { (sysctlOutput) in
            if let CPUInfo = sysctlOutput {
                MachineInformation.config.CPU = CPUInfo
            }
        }
    }

    private static func getDeviceInfo() {
        if DeviceIdentifier.isConfigured,
            let serialNumber = MachineInformation.config.serialNumber {
            DeviceIdentifier.shared.lookupAppleSerial(serialNumber) { (newDeviceInfo) in
                MachineInformation.config.deviceInfo = newDeviceInfo
            }
        }
    }

    public func openWarrantyLink() {
        var warrantyLink: URL? = nil
        if let deviceInfo = self.deviceInfo {
            warrantyLink = deviceInfo.coverageURL
        } else if let deviceIdentifier = self.deviceIdentifier,
            let cachedDeviceInfo = deviceIdentifier.getCachedDeviceFor(serialNumber: self.serialNumber) {
            warrantyLink = cachedDeviceInfo.coverageURL
        } else if !serialNumber.contains(Sysctl.model) {
            warrantyLink = URL(string: "https://checkcoverage.apple.com/?sn=\(serialNumber)")
        }

        if let validWarrantyLink = warrantyLink {
            NSWorkspace.shared.open(validWarrantyLink)
        }
    }

    // MARK: Computed properties
    public static var isConfigured: Bool {
        return self.config.isConfigured
    }

    public var modelIdentifier: String {
        return Sysctl.model
    }

    public var serialNumber: String {
        return NSApplication.shared.getSerialNumber() ?? "No serial found for machine \(Sysctl.model)"
    }

    public var displayName: String {
        if let deviceInfo = self.deviceInfo {
            return deviceInfo.configurationCode.skuHint
        } else if let deviceIdentifier = self.deviceIdentifier,
            let cachedDeviceInfo = deviceIdentifier.getCachedDeviceFor(serialNumber: self.serialNumber) {
            return cachedDeviceInfo.configurationCode.skuHint
        }

        return self.modelIdentifier
    }

    public var allDisksAndPartitions: [Any] {
        if let diskUtility = self.diskUtility {
            return diskUtility.getAllDisksAndPartitions()
        }

        return DiskUtility.shared.getAllDisksAndPartitions()
    }

    public var productImage: NSImage? {
        if let deviceInfo = self.deviceInfo {
            return deviceInfo.configurationCode.image
        } else if let deviceIdentifier = self.deviceIdentifier,
            let cachedDeviceInfo = deviceIdentifier.getCachedDeviceFor(serialNumber: self.serialNumber) {
            return cachedDeviceInfo.configurationCode.image
        }

        return NSImage(named: "AppleLogo")
    }

    public var hasEnoughRAMForInstall: Bool {
        return self.RAM.gigabytes >= 8.0
    }

    public var RAM: Units {
        return Units(bytes: Int64(ProcessInfo.processInfo.physicalMemory))
    }

    public var bootHDD: Disk? {
        let path = "/"
        let mountPoint = path.cString(using: .utf8)! as [Int8]
        var unsafeMountPoint = mountPoint.map { UInt8(bitPattern: $0) }

        if let fileURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, &unsafeMountPoint, Int(strlen(mountPoint)), true),
            let daSession = DASessionCreate(kCFAllocatorDefault),
            let daDisk = DADiskCreateFromVolumePath(kCFAllocatorDefault, daSession, fileURL) {
            print(daDisk)
        }

        return nil
    }

    public var isMetalCompatible: Bool {
        if #available(OSX 10.11, *) {
            let metalDevices = MTLCopyAllDevices()
            for metalDevice in metalDevices {
                let gpuName = stripGPUName(name: metalDevice.name)!
                if(!metalGPUs.contains(gpuName)) {
                    metalGPUs.append(gpuName)
                }
            }
        }

        let allGPUs = uniq(source: self.allGraphicsCards)

        metalGPUs = uniq(source: metalGPUs)
        nonMetalGPUs = allGPUs.filter { !metalGPUs.contains($0) }

        if(nonMetalGPUs.count > 0) {
            for(gpuName) in nonMetalGPUs {
                DDLogInfo(gpuName + " is not metal compatible")
                return false
            }
        }

        DDLogVerbose("No non-metal GPUs")
        return true
    }


    public var allGraphicsCards: [String] {
        let devices = IOServiceMatching("IOPCIDevice")
        var entryIterator: io_iterator_t = 0
        var gpus = [String]()

        if IOServiceGetMatchingServices(kIOMasterPortDefault, devices, &entryIterator) == kIOReturnSuccess {
            while case let device: io_registry_entry_t = IOIteratorNext(entryIterator), device != 0 {
                var serviceDictionary: Unmanaged<CFMutableDictionary>?

                if IORegistryEntryCreateCFProperties(device, &serviceDictionary, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                    IOObjectRelease(device)
                    continue
                }

                if let serviceDictionary = serviceDictionary {
                    let dict = serviceDictionary.takeRetainedValue() as NSDictionary

                    if let ioName = dict["IOName"] {
                        if CFGetTypeID(ioName as CFTypeRef) == CFStringGetTypeID() &&
                            CFStringCompare((ioName as! CFString), "display" as CFString, .compareCaseInsensitive) == .compareEqualTo {
                            if let model = dict["model"] as? Data,
                                let gpuName = stripGPUName(name: String(data: model, encoding: String.Encoding.ascii)) {
                                if(!gpus.contains(gpuName)) {
                                    gpus.append(gpuName)
                                }
                            }
                        }
                    }
                }
            }
        }
        return gpus
    }

    // MARK: Helpers
    private func stripGPUName(name: String?) -> String? {
        if let gpuName = name {
            return gpuName.replacingOccurrences(of: "Graphics", with: "").replacingOccurrences(of: "\0", with: "", options: NSString.CompareOptions.literal, range: nil).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }

}
