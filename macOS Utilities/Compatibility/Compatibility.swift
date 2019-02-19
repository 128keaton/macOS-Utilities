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

class Compatibility {
    private (set) public var modelIdentifier: String? = nil
    private (set) public var hasMetalGPU = false
    private (set) public var hasEnoughMemory = false
    private (set) public var hasLargeEnoughHDD = false
    private (set) public var incompatibleGPUs = [String]()
    private var installableVersions = ModelYearDetermination().determineInstallableVersions()

    init() {
        modelIdentifier = ModelYearDetermination().modelIdentifier
        getMetalCompatibility()
        checkMemory()
        checkHDD()
    }

    func canInstall(version: String) -> Bool {
        return installableVersions.contains(version)
    }

    func checkMemory() {
        let memoryInGB = Int((Sysctl.memSize) / 1024000000)
        if(memoryInGB < 8) {
            hasEnoughMemory = false
        } else {
            hasEnoughMemory = true
        }
    }
    
    func checkHDD(){
        let hddSpaceInGB = getTotalSizeGB()
        if(hddSpaceInGB < 150){
            hasLargeEnoughHDD = false
        }else{
            hasLargeEnoughHDD = true
        }
    }
    
    func getTotalSizeGB() -> Int{
        return Int(ceil(Double(getTotalSize()! / 1000000000)))
    }
    
    func getTotalSize() -> Int64?{
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if let dictionary = try? FileManager.default.attributesOfFileSystem(forPath: paths.last!) {
            if let freeSize = dictionary[FileAttributeKey.systemSize] as? NSNumber {
                return freeSize.int64Value
            }
        }else{
            print("Error Obtaining System Memory Info:")
        }
        return nil
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
                print(gpuName + " is not metal compatible")
                incompatibleGPUs.append(gpuName)
            }
        } else {
            print("No non-metal GPUs")
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
    func stripGPUName(name: String?) -> String? {
        if let gpuName = name {
            return gpuName.replacingOccurrences(of: "Graphics", with: "").replacingOccurrences(of: "\0", with: "", options: NSString.CompareOptions.literal, range: nil).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
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
