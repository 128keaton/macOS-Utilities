//
//  SystemProfiler.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Cocoa
import CocoaLumberjack

class SystemProfiler {
    private static var propertyListData: Data = Data()
    private static var detailedCPUInfoData: Data = Data()
    private static var hasParsed: Bool = false
    private static var metalGraphicsCardModels = [String]()
    private static var nonMetalGraphicsCardModels = [String]()

    public static var delegate: SystemProfilerDelegate? = nil
    public static var audioItems: [AudioItem] = []
    public static var discBurningItems: [DiscBurningItem] = []
    public static var displayItems: [DisplayItem] = []
    public static var hardwareItem: HardwareItem? = nil
    public static var memoryItems: [MemoryItem] = []
    public static var NVMeItems: [NVMeItem] = []
    public static var powerItems: [PowerItem] = []
    public static var serialATAItems: [SerialATAItem] = []

    private (set) public static var hasNonMetalGPU = false

    public static let dataWasParsed = Notification.Name("SystemProfilerDataParsed")

    public static var hasMachineData: Bool {
        return self.hardwareItem != nil
    }

    public static func getInfo(force: Bool = false) {
        if hasParsed && !force {
            NotificationCenter.default.post(name: dataWasParsed, object: nil)

            if let _delegate = self.delegate {
                _delegate.dataParsedSuccessfully()
            } else {
                print("Data has already been parsed")
            }
            return
        }

        let launchPath = "/usr/sbin/system_profiler"
        if !FileManager.default.isExecutableFile(atPath: launchPath) {
            return
        }

        self.getDetailedCPUInfo()

        let infoTask = Process()
        let standardPipe = Pipe()

        infoTask.launchPath = launchPath
        infoTask.arguments = ["-xml", "-detailLevel", "full", "SPAudioDataType", "SPBluetoothDataType", "SPCameraDataType", "SPCardReaderDataType", "SPDiagnosticsDataType", "SPDisplaysDataType", "SPHardwareDataType", "SPMemoryDataType", "SPNetworkDataType", "SPPowerDataType", "SPNVMeDataType", "SPAirPortDataType", "SPSerialATADataType", "DPDiscBurningDataType"]

        infoTask.standardOutput = standardPipe


        let readHandle = standardPipe.fileHandleForReading

        NotificationCenter.default.addObserver(self, selector: #selector(savePropertyListData(_:)), name: FileHandle.readCompletionNotification, object: readHandle)
        NotificationCenter.default.addObserver(self, selector: #selector(parseAllData(_:)), name: Process.didTerminateNotification, object: nil)

        infoTask.launch()
        readHandle.readInBackgroundAndNotify()
    }

    public static func graphicsCardIsMetalCapable(graphicsCardModel model: String) -> Bool {
        return self.metalGraphicsCardModels.contains(model)
    }

    private static func getDetailedCPUInfo() {
        let launchPath = "/usr/sbin/sysctl"
        if !FileManager.default.isExecutableFile(atPath: launchPath) {
            return
        }

        let infoTask = Process()
        let standardPipe = Pipe()

        infoTask.launchPath = launchPath
        infoTask.arguments = ["-n", "machdep.cpu.brand_string"]
        infoTask.standardOutput = standardPipe

        let readHandle = standardPipe.fileHandleForReading

        NotificationCenter.default.addObserver(self, selector: #selector(saveDetailedCPUInfoData(_:)), name: FileHandle.readCompletionNotification, object: readHandle)
        NotificationCenter.default.addObserver(self, selector: #selector(parseAllData(_:)), name: Process.didTerminateNotification, object: nil)

        infoTask.launch()
        readHandle.readInBackgroundAndNotify()
    }

    @objc static func savePropertyListData(_ notification: Notification) {
        if let fileHandle = notification.object as? FileHandle,
            let userInfo = notification.userInfo as? [String: Any],
            let newData = userInfo[NSFileHandleNotificationDataItem] as? Data, newData.count > 0 {

            DDLogVerbose("Appending to propertyListData")
            self.propertyListData.append(newData)

            fileHandle.readInBackgroundAndNotify()
        }
    }

    @objc static func saveDetailedCPUInfoData(_ notification: Notification) {
        if let fileHandle = notification.object as? FileHandle,
            let userInfo = notification.userInfo as? [String: Any],
            let newData = userInfo[NSFileHandleNotificationDataItem] as? Data, newData.count > 0 {

            DDLogVerbose("Appending to detailedCPUInfoData")
            self.detailedCPUInfoData.append(newData)

            fileHandle.readInBackgroundAndNotify()
        }
    }

    @objc static func parseAllData(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.propertyListData.count > 0, self.detailedCPUInfoData.count > 0, !hasParsed {
                self.hasParsed = true
                self.parseInto(self.propertyListData)
            }
        }
    }

    public static func condense() -> CondensedSystemProfilerData {
        var allData: [[ItemType]] = [self.audioItems, self.discBurningItems, self.displayItems,
            self.memoryItems, self.NVMeItems, self.powerItems, self.NVMeItems]

        if let validHardwareItem = self.hardwareItem {
            allData.append([validHardwareItem])
        }

        return CondensedSystemProfilerData(from: allData)
    }

    private static func matchTypes(_ unmatchedItems: [SystemProfilerItem]) {
        for anItem in unmatchedItems {
            switch anItem.dataType {
            case .audio:
                self.audioItems = anItem.getItems(AudioItem.self)
                break
            case .discBurning:
                self.discBurningItems = anItem.getItems(DiscBurningItem.self)
                break
            case .display:
                self.displayItems = anItem.getItems(DisplayItem.self)
                break
            case .hardware:
                self.hardwareItem = anItem.getItems(HardwareItem.self).first
                break
            case .memory:
                self.memoryItems = anItem.getItems(MemoryItem.self)
                break
            case .NVMe:
                self.NVMeItems = anItem.getItems(NVMeItem.self)
                break
            case .power:
                self.powerItems = anItem.getItems(PowerItem.self)
                break
            case .serialATA:
                self.serialATAItems = anItem.getItems(SerialATAItem.self)
                break
            case .invalid:
                DDLogVerbose("An invalid item was attempted to match against: \(anItem)")
                break
            }
        }
    }

    static func parseInto(_ data: Data) {
        do {
            let decoder = PropertyListDecoder()

            SystemProfilerItem.register(DisplayItem.self, for: .display)
            SystemProfilerItem.register(HardwareItem.self, for: .hardware)
            SystemProfilerItem.register(NestedMemoryItem.self, for: .memory)
            SystemProfilerItem.register(NestedAudioItem.self, for: .audio)
            SystemProfilerItem.register(PowerItem.self, for: .power)
            SystemProfilerItem.register(NVMeItem.self, for: .NVMe)
            SystemProfilerItem.register(DiscBurningItem.self, for: .discBurning)
            SystemProfilerItem.register(SerialATAControllerItem.self, for: .serialATA)

            let unmatchedTypes = try decoder.decode([SystemProfilerItem].self, from: data)
            self.matchTypes(unmatchedTypes)

            print(unmatchedTypes)

            if let validHardwareItem = self.hardwareItem,
                let detailedCPUInfo = String(data: detailedCPUInfoData, encoding: .utf8) {
                validHardwareItem.cpuType = detailedCPUInfo
            } else {
                DDLogInfo("Could not get a valid hardware item")
            }

            for graphicsCard in self.displayItems {
                if !graphicsCard.isMetalCompatible {
                    self.nonMetalGraphicsCardModels.append(graphicsCard.graphicsCardModel)
                } else {
                    self.metalGraphicsCardModels.append(graphicsCard.graphicsCardModel)
                }
            }

            NotificationCenter.default.post(name: dataWasParsed, object: nil)

            if let _delegate = self.delegate {
                _delegate.dataParsedSuccessfully()
            } else {
                DDLogVerbose("Data parsed successfully")
            }

        } catch {
            self.hasParsed = false
            if let _delegate = self.delegate {
                _delegate.handleError(error)
            } else {
                DDLogError("Error parsing SystemProfilerData: \(error)")
            }
        }
    }

    public static var modelIdentifier: String {
        if let hardwareInfo = self.hardwareItem, let machineModel = hardwareInfo.machineModel {
            return machineModel
        }
        return Sysctl.model
    }

    public static var serialNumber: String {
        if let hardwareInfo = self.hardwareItem, let serialNumber = hardwareInfo.serialNumber {
            return serialNumber
        }

        return NSApplication.shared.getSerialNumber() ?? "No serial found for machine \(Sysctl.model)"
    }

    public static var anonymisedSerialNumber: String {
        return "••••••\(self.serialNumber.dropFirst(6))"
    }

    public static var hasBootDisk: Bool {
        if let bootDisk = DiskUtility.bootDisk {
            return bootDisk.volumeName == "Macintosh HD" && bootDisk.size.gigabytes >= 110.0
        }

        return false
    }

    public static var graphicsCardInformation: String {
        if self.nonMetalGraphicsCardModels.count > 0 {
            self.hasNonMetalGPU = true
            return "This machine has a non-Metal compatible graphics card installed: \n \(self.nonMetalGraphicsCardModels.joined(separator: "\n"))"
        }

        if self.metalGraphicsCardModels.count > 0 {
            return "This machine has a Metal compatible graphics card installed: \n \(self.metalGraphicsCardModels.first!)"
        }

        return "Could not determine what graphics cards are installed"
    }

    public static var memoryRequirementSatisfied: Bool {
        if let hardwareInfo = self.hardwareItem, hardwareInfo.doubleMemory >= 8.0 {
            DDLogVerbose("Machine has satisfied/exceeded the memory requirements of 8.0GB")
            return true
        }

        KBLogDebug("Could not calculate how much memory was installed")
        return false
    }

    public static var memoryInformation: String {
        if let hardwareInfo = self.hardwareItem {
            if memoryRequirementSatisfied {
                DDLogVerbose("This machine has more than 8 GB of RAM")
                return "This machine has more than 8 GB of RAM"
            } else if hardwareInfo.doubleMemory > 0.0 {
                DDLogVerbose("This machine has \(Int(hardwareInfo.doubleMemory)) GB of RAM")
                return "This machine has \(Int(hardwareInfo.doubleMemory)) GB of RAM"
            }
        }

        KBLogDebug("Could not calculate how much memory was installed")
        return "Could not calculate how much memory was installed"
    }

    public static var amountOfMemoryInstalled: Double {
        if let hardwareInfo = self.hardwareItem, hardwareInfo.doubleMemory > 0.0 {
            return hardwareInfo.doubleMemory
        }

        KBLogDebug("Could not calculate how much memory was installed")
        return 0.0
    }


    public static var processorInformation: String {
        if let hardwareInfo = self.hardwareItem, let cpuType = hardwareInfo.cpuType {
            return cpuType.replacingOccurrences(of: "  ", with: "").replacingOccurrences(of: "(R)", with: "®")
        }

        return "Unable to determine processor information"
    }

    public static var bootDiskInformation: String {
        if self.hasBootDisk, let bootDisk = DiskUtility.bootDisk {
            return "\(bootDisk.volumeName) is available and has a size of \(bootDisk.size.getReadableUnit())"
        }

        return "No installable hard drive found"
    }

    public static var metalRequirementStatus: NSImage {
        if self.hasNonMetalGPU, self.displayItems.count > 0 {
            return NSImage(named: "NSStatusUnavailable")!
        }

        return NSImage(named: "NSStatusAvailable")!
    }

    public static var installableHardDiskRequirementStatus: NSImage {
        if self.hasBootDisk {
            return NSImage(named: "NSStatusAvailable")!
        }

        return NSImage(named: "NSStatusUnavailable")!
    }

    public static var memoryRequirementStatus: NSImage {
        return self.memoryRequirementSatisfied ? NSImage(named: "NSStatusAvailable")! : NSImage(named: "NSStatusUnavailable")!
    }

    public static var barcodeImage: NSImage {
        if let validBarcode = BarcodeGenerator.fromString(self.serialNumber) {
            return validBarcode
        }

        return NSImage(named: "NSAppleIcon")!
    }
}

enum SPDataType: String {
    case display = "SPDisplaysDataType"
    case hardware = "SPHardwareDataType"
    case memory = "SPMemoryDataType"
    case audio = "SPAudioDataType"
    case power = "SPPowerDataType"
    case NVMe = "SPNVMeDataType"
    case discBurning = "DPDiscBurningDataType"
    case serialATA = "SPSerialATADataType"
    case invalid = "SPInvalidDataType"
}

protocol SystemProfilerDelegate {
    func dataParsedSuccessfully()
    func handleError(_ error: Error)
}
