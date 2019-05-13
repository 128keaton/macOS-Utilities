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
    private var bootDisk: Disk? = nil

    private (set) public var metalGPUs: [String] = []
    private (set) public var nonMetalGPUs: [String] = []

    // Put GPUs here..mine is funky
    private (set) public var metalGPUsOverrides = ["AMD Radeon HD 7xxx"]
    private var cachedCPU: String = String()

    static let shared = MachineInformation()
    private static let config = Config()

    // MARK: Initializers
    private init() {
        if let deviceInfo = MachineInformation.config.deviceInfo {
            self.deviceInfo = deviceInfo
        }

        if let CPU = MachineInformation.config.CPU {
            self.cachedCPU = CPU
        }

        NotificationCenter.default.addObserver(self, selector: #selector(bootDiskAvailable(_:)), name: DiskUtility.bootDiskAvailable, object: nil)
        parseGPUInfo()
    }

    // MARK: Functions

    public func getCPU(_ returnHandler: @escaping (String) -> ()) {
        if self.cachedCPU != "" {
            returnHandler(cachedCPU)
        } else {
            TaskHandler.createTask(command: "/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"]) { (sysctlOutput) in
                if let CPUInfo = sysctlOutput {
                    self.cachedCPU = CPUInfo
                    returnHandler(CPUInfo)
                }
            }
        }
    }

    @objc private func bootDiskAvailable(_ aNotification: Notification? = nil) {
        if let notification = aNotification,
            let bootDisk = notification.object as? Disk {
            self.bootDisk = bootDisk
        } else if let bootDisk = DiskUtility.shared.bootDisk {
            self.bootDisk = bootDisk
        }
    }

    private func parseGPUInfo() {
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


        let existingOverrides = metalGPUs.filter { metalGPUsOverrides.contains($0) }
        if existingOverrides.count > 1 {
            DDLogInfo("\(existingOverrides.joined(separator: ", ")) are already flagged as Metal GPUs, you can remove them from the overrides")
        }

        metalGPUs.append(contentsOf: self.metalGPUsOverrides)
        metalGPUs = uniq(source: metalGPUs)
        nonMetalGPUs = allGPUs.filter { !metalGPUs.contains($0) }

        if(nonMetalGPUs.count > 0) {
            for(gpuName) in nonMetalGPUs {
                DDLogInfo(gpuName + " is not metal compatible")
            }
        }

        DDLogVerbose("No non-metal GPUs")
    }

    static func setup(deviceIdentifier: DeviceIdentifier) {
        if DeviceIdentifier.isConfigured {
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
            getDeviceInfo()
        }

        MachineInformation.config.diskUtility = DiskUtility.shared
        MachineInformation.config.isConfigured = true

        getCPUInfo()
        getDeviceInfo()
    }

    static func setup(diskUtility: DiskUtility) {
        if DeviceIdentifier.isConfigured {
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
            getDeviceInfo()
        }

        MachineInformation.config.diskUtility = diskUtility
        MachineInformation.config.isConfigured = true

        getCPUInfo()
    }

    static func setup(deviceIdentifier: DeviceIdentifier, diskUtility: DiskUtility) {
        if DeviceIdentifier.isConfigured {
            MachineInformation.config.deviceIdentifier = DeviceIdentifier.shared
            getDeviceInfo()
        }

        MachineInformation.config.diskUtility = diskUtility
        MachineInformation.config.isConfigured = true

        getCPUInfo()
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

    private func initializeDeviceInfo() {
        if self.deviceIdentifier == nil && DeviceIdentifier.isConfigured {
            self.deviceIdentifier = DeviceIdentifier.shared
        } else {
            DDLogVerbose("DeviceIdentifier API not in use")
        }

        if self.deviceInfo == nil,
            let deviceIdentifier = self.deviceIdentifier {
            self.deviceInfo = deviceIdentifier.getCachedDeviceFor(serialNumber: self.serialNumber)
        } else if self.deviceIdentifier == nil {
            DDLogVerbose("DeviceIdentifier API not in use")
        }
    }

    public func graphicsCardIsMetal(_ graphicsCard: String) -> Bool {
        return self.metalGPUs.contains(graphicsCard)
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

    public var anonymisedSerialNumber: String {
        if let deviceInfo = self.deviceInfo {
            return deviceInfo.anonymised
        }

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

    public var GPUInformation: String {
        if self.nonMetalGPUs.count > 0 {
            return "This machine has a non-Metal compatible graphics card installed: \n \(self.nonMetalGPUs.joined(separator: "\n"))"
        }

        if self.metalGPUs.count > 0 {
            return "This machine has a Metal compatible graphics card installed: \n \(self.metalGPUs.first!)"
        }

        return "Could not determine what graphics cards are installed"
    }

    public var RAMInformation: String {
        if self.RAM.gigabytes >= 8.0 {
            return "This machine has more than 8 GB of RAM"
        }

        return "This machine has \(Int(self.RAM.gigabytes)) GB of RAM"
    }

    public var HDDInformation: String {
        if let bootDisk = self.bootDisk {
            if bootDisk.volumeName == "Macintosh HD" && bootDisk.size.gigabytes >= 110.0 {
                return "\(bootDisk.volumeName) is available and has a size of \(bootDisk.size.getReadableUnit())"
            } else if bootDisk.volumeName == "Macintosh HD" {
                return "\(bootDisk.volumeName) is available but does not have enough space for installation. (110 GB > \(bootDisk.size.getReadableUnit()))"
            } else {
                return "\(bootDisk.volumeName) needs to be \"Macintosh HD\""
            }
        }

        return "No installable hard drive found"
    }

    public var HDDStatus: NSImage {
        return self.bootHDDIsValid ? NSImage(named: "NSStatusAvailable")! : NSImage(named: "NSStatusUnavailable")!
    }

    public var GPUStatus: NSImage {
        if self.nonMetalGPUs.count > 0 {
            return NSImage(named: "NSStatusUnavailable")!
        }

        if self.metalGPUs.count > 0 {
            return NSImage(named: "NSStatusAvailable")!
        }

        return NSImage(named: "NSStatusUnavailable")!
    }

    public var RAMStatus: NSImage {
        return self.RAM.gigabytes >= 8.0 ? NSImage(named: "NSStatusAvailable")! : NSImage(named: "NSStatusUnavailable")!
    }

    public var productImage: NSImage {
        if let deviceInfo = self.deviceInfo {
            if let productImage = deviceInfo.configurationCode.image {
                return productImage
            } else if deviceInfo.configurationCode.imageURL != nil {
                deviceInfo.configurationCode.getImage()
                if let productImage = deviceInfo.configurationCode.image {
                    return productImage
                }
            }
        }

        return NSImage(named: "NSAppleIcon")!
    }

    public var hasEnoughRAMForInstall: Bool {
        return self.RAM.gigabytes >= 8.0
    }

    public var RAM: Units {
        return Units(bytes: Int64(ProcessInfo.processInfo.physicalMemory))
    }

    public var hasBootHDD: Bool {
        return self.bootDisk != nil
    }

    public var bootHDDIsValid: Bool {
        if let bootDisk = self.bootDisk {
            return (bootDisk.volumeName == "Macintosh HD" && bootDisk.size.gigabytes >= 110.0)
        }

        return false
    }

    public var isMetalCompatible: Bool {
        if self.metalGPUs.count > 0 && self.nonMetalGPUs.count == 0 {
            return true
        }
        return false
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
