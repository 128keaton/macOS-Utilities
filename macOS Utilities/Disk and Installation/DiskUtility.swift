//
//  DiskUtility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class DiskUtility {
    public static let shared = DiskUtility()
    private var cachedDisks = [Disk]()
    
    private init() {

    }

    public func getAllDisks() {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["list", "-plist"]) { (output) in
            if let plistOutput = output {
                let diskImageInfo = self.parseDiskUtilList(plistOutput)
                if let allDisks = diskImageInfo["AllDisksAndPartitions"] as? [NSDictionary] {
                    self.cachedDisks = allDisks.map { Disk(diskDictionary: $0) }
                }
            }
        }
    }

    public func mountDiskImagesAt(_ folderPath: String) {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            for file in fileURLs {
                let fileName = file.lastPathComponent
                if(fileName.contains(".dmg")) {
                    let diskImagePath = "\(folderURL.absoluteString.replacingOccurrences(of: "file://", with: ""))\(fileName)"
                    self.mountDiskImage(diskImagePath)
                } else {
                    DDLogError("\(fileName) is not a valid DMG")
                }
            }
        } catch {
            DDLogError("Unable to list directory: \(folderURL)")
        }
    }

    public func mountDiskImage(_ at: String) {
        if(at.contains(".dmg")) {
            DDLogError("Disk \(at) is not a disk image or is not mountable")
        }

        TaskHandler.createTask(command: "/usr/bin/hdiutil", arguments: ["mount", "-plist", "\(at)", "-noverify"]) { (taskOutput) in
            DDLogInfo("Mounting \(at)")

            if((taskOutput?.contains("hdiutil: mount failed"))!) {
                DDLogError("Disk \(at) could not be mounted: \n")
                DDLogError(taskOutput!)
            } else {
                if let hdiutilOutput = taskOutput {
                    print(hdiutilOutput)
                }
            }
        }
    }

    // Returns an NSDictionary with the contents of the system-entities
    private func parseDiskUtilList(_ diskUtilOutput: String) -> NSDictionary {
        var errorDescription: String? = nil
        var validDictionary = NSDictionary()

        if let diskImageRawData = diskUtilOutput.data(using: .utf8) {
            do {
                if let potentialDictionary = try PropertyListSerialization.propertyList(from: diskImageRawData, options: [], format: nil) as? NSDictionary {
                    validDictionary = potentialDictionary
                } else {
                    errorDescription = "Output did not contain valid disk info. \n \(diskUtilOutput)"
                }

            } catch let error as NSError {
                errorDescription = error.localizedDescription
            }
        } else {
            errorDescription = "Output was invalid: \n \(diskUtilOutput)"
        }

        if let errorDescriptionString = errorDescription {
            DDLogError("Could not parse disk image info: \(errorDescriptionString)")
        }

        return validDictionary
    }
}
