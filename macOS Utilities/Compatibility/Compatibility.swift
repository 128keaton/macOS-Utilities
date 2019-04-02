//
//  Compatibility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import IOKit
import CocoaLumberjack

class Compatibility {
    private (set) public var modelIdentifier: String? = nil
    private (set) public var hasMetalGPU = false
    private (set) public var hasEnoughMemory = false
    private (set) public var hasFormattedHDD = false
    private (set) public var hasLargeEnoughHDD = false
    private (set) public var incompatibleGPUs = [String]()
    private (set) public var storageDeviceSize = Double(){
        didSet{
            checkHDD()
        }
    }
    
    private var installableVersions = ModelYearDetermination().determineInstallableVersions()

    init() {
        modelIdentifier = ModelYearDetermination().modelIdentifier
        getMetalCompatibility()
        checkMemory()
        getInstallableHDD()
    }

    public func canInstall(version: String) -> Bool {
        return installableVersions.contains(version)
    }

    public func checkMemory() {
        let memoryInGB = Int((Sysctl.memSize) / 1024000000)
        if(memoryInGB < 8) {
            hasEnoughMemory = false
            DDLogError("Machine does NOT have enough memory")
        } else {
            hasEnoughMemory = true
            DDLogVerbose("Machine has enough memory")
        }
    }

    public func checkHDD() {
        if(storageDeviceSize < 150.0) {
            hasLargeEnoughHDD = false
            DDLogError("Machine does NOT have a storage device large enough")
        } else {
            hasLargeEnoughHDD = true
            DDLogVerbose("Machine has a storage device large enough")
        }
    }

    // Basic check to see if Macintosh HD is present, if not, check if volume is netbooted
    public func getInstallableHDD() {
        let hddName = "Macintosh HD"
        DDLogInfo("Checking for volume named \(hddName)")
        if let foundHDD = handleTask(command: "/usr/sbin/diskutil", arguments: ["info", hddName]) {
            let diskSizes = matches(for: "([0-9]){1,4}.*.GB", in: foundHDD)
            DDLogInfo("Disk sizes found: \(diskSizes)")

            if let size = diskSizes.first {
                hasFormattedHDD = true
                if let doubleSize = Double(size.replacingOccurrences(of: " GB", with: "")) {
                    DDLogInfo("\(hddName) is available and the size is \(doubleSize)")
                    storageDeviceSize = doubleSize
                    return
                }
            }
        }
        
        DDLogInfo("No formatted HDD Found")
        hasFormattedHDD = false
        storageDeviceSize = 0.0
    }

    private func handleTask(command: String, arguments: [String]) -> String? {
        let task = Process()
        let errorPipe = Pipe()
        let standardPipe = Pipe()

        task.standardError = errorPipe
        task.standardOutput = standardPipe

        task.launchPath = command
        task.arguments = arguments

        task.launch()
        task.waitUntilExit()

        let errorHandle = errorPipe.fileHandleForReading
        let errorData = errorHandle.readDataToEndOfFile()
        let taskErrorOutput = String (data: errorData, encoding: String.Encoding.utf8)

        let standardHandle = standardPipe.fileHandleForReading
        let standardData = standardHandle.readDataToEndOfFile()
        let taskStandardOutput = String (data: standardData, encoding: String.Encoding.utf8)

        if(taskErrorOutput != nil) {
            return String("\(taskErrorOutput ?? "No errors")\n\(taskStandardOutput ?? "No standard output")")
        }

        return taskStandardOutput
    }

    // Determines metal compatibility
    private func getMetalCompatibility() {
        var metalGPUs = [String]()
        if #available(OSX 10.11, *) {
            let metalDevices = MTLCopyAllDevices()
            for metalDevice in metalDevices {
                hasMetalGPU = true
                let gpuName = stripGPUName(name: metalDevice.name)!
                if(!metalGPUs.contains(gpuName)) {
                    metalGPUs.append(gpuName)
                }
            }
        }

        metalGPUs = uniq(source: metalGPUs)
        let allGPUs = uniq(source: getAllGPUs())
        let nonMetalGPUs = allGPUs.filter { !metalGPUs.contains($0) }

        if(nonMetalGPUs.count > 0) {
            for(gpuName) in nonMetalGPUs {
                DDLogInfo(gpuName + " is not metal compatible")
                incompatibleGPUs.append(gpuName)
            }
        } else {
            DDLogVerbose("No non-metal GPUs")
            DDLogVerbose("High Sierra can be installed on this machine")
        }
    }

    // Gets all of the GPUs on the PCIe bus
    private func getAllGPUs() -> [String] {
        let devices = IOServiceMatching("IOPCIDevice")
        var entryIterator: io_iterator_t = 0
        var gpus = [String]()

        if IOServiceGetMatchingServices(kIOMasterPortDefault, devices, &entryIterator) == kIOReturnSuccess {
            while case let device: io_registry_entry_t = IOIteratorNext(entryIterator), device != 0 {
                var serviceDictionary: Unmanaged<CFMutableDictionary>?

                if IORegistryEntryCreateCFProperties(device, &serviceDictionary, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                    // Couldn't get the properties for this service, so clean up and
                    // continue.
                    IOObjectRelease(device)
                    continue
                }

                if let serviceDictionary = serviceDictionary {
                    let dict = serviceDictionary.takeRetainedValue() as NSDictionary

                    if let ioName = dict["IOName"] {
                        // If we have an IOName, and its value is "display", then we've
                        // got a "model" key, whose value is a CFDataRef that we can
                        // convert into a string.
                        if CFGetTypeID(ioName as CFTypeRef) == CFStringGetTypeID() &&
                            CFStringCompare((ioName as! CFString), "display" as CFString, .compareCaseInsensitive) == .compareEqualTo {
                            let model = dict["model"]
                            if let gpuName = stripGPUName(name: String(data: model as! Data, encoding: String.Encoding.ascii)) {
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

    // Essential for comparing GPUs to find which one is the odd man out
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
