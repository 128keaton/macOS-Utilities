//
//  DiskUtility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/2/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//  Wrapper for hdiutil, diskutil, and mount all in one :)

import Foundation
import CocoaLumberjack

class DiskUtility {
    public static let shared = DiskUtility()

    private var diskImageUtility: DiskImageUtility? = nil
    private var networkShareUtility: NetworkShareUtility? = nil

    private var physicalDisks = [Disk]()

    private init() {
        self.diskImageUtility = DiskImageUtility(diskUtility: self)
        self.networkShareUtility = NetworkShareUtility(diskUtility: self)
    }

    public func getAllDisks(mountedOnly: Bool = true, refresh: Bool = false, diskHandler: @escaping([Disk]) -> ()) {
        var returnedDisks = [Disk]()

        if(refresh || self.physicalDisks.count == 0) {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["list"]) { (allDisks) in
                let matchedDisks = allDisks!.matches("(Apple_APFS|Apple_HFS|APFS Volume).\\b(?!Container)\\b.*([0-9]+( |.[0-9]+ )(GB|TB))+ *disk([0-9]*)s[0-99]")


                var watchedDisks = [Disk]()
                var stillWatching = true

                for matchedDiskOutput in matchedDisks {
                    let newDisk = Disk(diskType: .physical, matchedDiskOutput: matchedDiskOutput)
                    newDisk.devEntry = matchedDiskOutput.split { $0 == " " }.map(String.init).last!

                    watchedDisks.append(newDisk)

                    newDisk.mountAction = DiskAction {
                        returnedDisks.append(newDisk)
                    }
                }

                while (stillWatching == true) {
                    if(watchedDisks.count == returnedDisks.count) {
                        stillWatching = false
                        self.physicalDisks = returnedDisks
                        diskHandler(returnedDisks)
                    }
                }
            }
        } else {
            diskHandler(self.physicalDisks)
        }
    }

    public func getNameForDisk(_ disk: Disk, returnEscaping: @escaping(String) -> ()) {
        if let mountedDisk = disk.mountedDisk {
            getRawDiskInfo(mountedDisk: mountedDisk) { (diskInfo) in
                if let diskInfo = diskInfo {
                    if let volumeName = diskInfo.matches("Volume Name: *.*").first {
                        returnEscaping(volumeName.replacingOccurrences(of: "Volume Name: *", with: "", options: .regularExpression))
                    }
                }
            }
        }
    }

    public func getNameForDisk(_ mountedDisk: MountedDisk, returnEscaping: @escaping(String) -> ()) {
        getRawDiskInfo(mountedDisk: mountedDisk) { (diskInfo) in
            if let diskInfo = diskInfo {
                if let volumeName = diskInfo.matches("Volume Name: *.*").first {
                    returnEscaping(volumeName.replacingOccurrences(of: "Volume Name: *", with: "", options: .regularExpression))
                }
            }
        }

    }

    // Can be any kind of valid and defined disk
    public func mount(disk: Disk, returnEscaping: @escaping (MountedDisk?) -> ()) {
        if(disk.isRemoteDisk == true && disk.diskType == .nfs) {
            networkShareUtility?.mount(disk) { (mountedDisk) in
                returnEscaping(mountedDisk)
            }
        } else if(disk.diskType == .dmg) {
            diskImageUtility?.mount(disk) { (mountedDisk) in
                returnEscaping(mountedDisk)
            }
        } else if(disk.diskType == .physical) {
            DDLogInfo("Physical disk mounting is handled by the system automatically")
        }
        returnEscaping(nil)
    }

    public func getRawDiskInfo(mountedDisk: MountedDisk, returnCompletion: @escaping (String?) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", mountedDisk.devEntry]) { (diskInfo) in
            returnCompletion(diskInfo)
        }
    }

    public func getRawDiskInfo(path: String, returnCompletion: @escaping (String?) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", path]) { (diskInfo) in
            returnCompletion(diskInfo)
        }
    }

    // Creates a directory at a path for a drive to mount. Returns true or false if the directory was able to be created
    public func createMountPath(path: String) -> Bool {
        let newMountPath = URL(fileURLWithPath: path)

        if(newMountPath.filestatus == .isNot) {
            DDLogInfo("Creating directory at \(path)!)")
            return TaskHandler.createTaskWithStatus(command: "/bin/mkdir", arguments: [path])
        }

        DDLogInfo("Temporary path \(path) already exists.")
        return true
    }
}

fileprivate class NetworkShareUtility {
    private let badErrorWords = ["can't", "denied", "error"].flatMap { $0.components(separatedBy: " ") }

    private var diskUtility: DiskUtility? = nil

    init(diskUtility: DiskUtility) {
        self.diskUtility = diskUtility
        DDLogInfo("Network Share Utility initialized.")
    }

    public func mount(_ networkShare: Disk, returnCompletion: @escaping (MountedDisk?) -> ()) {
        if let mountPath = networkShare.mountPath {
            if (diskUtility?.createMountPath(path: mountPath))! {
                TaskHandler.createTask(command: "/sbin/mount", arguments: ["-t", "nfs", "-o", "soft,intr,rsize=8192,wsize=8192,timeo=900,retrans=3,proto=tcp", networkShare.path!, mountPath]) { (taskOutput) in
                    if(self.mountTaskSucceeded(taskOutput)) {
                        networkShare.mountAction = DiskAction { returnCompletion(networkShare.mountedDisk) }
                        if let validMountedDisk = networkShare.mountedDisk {
                            returnCompletion(validMountedDisk)
                        }
                    }
                }
            } else {
                DDLogInfo("Unable to create mount path at \(mountPath) for: \n \(networkShare)")
            }
        } else {
            DDLogError("Network Share does not contain a valid mountPath: \n \(networkShare)")
        }
    }

    private func mountTaskSucceeded(_ taskOutput: String?) -> Bool {
        if let mountOutput = taskOutput {
            if(badErrorWords.filter { mountOutput.range(of: $0) != nil }.count != 0) {
                DDLogError("Mounting network share failed on: \(mountOutput)")
                return false
            }
        }
        return true
    }

    func mountStatusChanged() {

    }
}

fileprivate class DiskImageUtility {
    private var diskImages = [Disk]()
    private var mountedDiskImages = [Disk]()
    private var diskUtility: DiskUtility? = nil

    init(diskUtility: DiskUtility) {
        self.diskUtility = diskUtility
        DDLogInfo("Disk Image Utility initialized.")
    }

    public func mount(_ diskImage: Disk, returnCompletion: @escaping (MountedDisk?) -> ()) {
        if(diskImage.diskType != .dmg && diskImage.isMountable) {
            DDLogError("Disk \(diskImage) is not a disk image or is not mountable")
            returnCompletion(nil)
        }

        TaskHandler.createTask(command: "/usr/bin/hdiutil", arguments: ["mount", "-plist", "\(diskImage.path!)", "-noverify"]) { (taskOutput) in
            DDLogInfo("Mounting \(diskImage.path!)")

            if((taskOutput?.contains("hdiutil: mount failed"))!) {
                DDLogError("Disk \(diskImage.path ?? "No path") could not be mounted: \n")
                DDLogError(taskOutput!)
                returnCompletion(nil)
            } else {
                if let hdiutilOutput = taskOutput {
                    let diskImageInfo = self.parseDiskImageInfo(hdiutilOutput)
                    if let mountPath = self.getDiskImageMountPoint(diskImageInfo) {
                        let existingDisk = self.diskImages.filter { $0.mountPath == mountPath && $0.mountedDisk !== nil }.first
                        if(existingDisk == nil) {
                            self.createMountedDiskFromDiskImage(mountPath: mountPath, disk: diskImage) { (newMountedDisk) in
                                self.mountedDiskImages.append(diskImage)
                                diskImage.mountedDisk = newMountedDisk
                                returnCompletion(newMountedDisk)
                            }
                        } else {
                            DDLogInfo("Disk already mounted: \n \(existingDisk!.description)")
                            returnCompletion(existingDisk!.mountedDisk!)
                        }
                    }
                }
            }
            returnCompletion(nil)
        }
    }

    // Returns the suggested disk image mount point as defined in the hdiutil info plist
    private func getDiskImageMountPoint(_ diskImageInfo: [[String: Any]]) -> String? {
        if let firstPotentiallyMountable = (diskImageInfo.filter { ($0["potentially-mountable"] as! Int) == 1 }.first) {
            guard let mountPath = firstPotentiallyMountable["mount-point"] as? String
                else {
                    return nil
            }
            return mountPath
        }

        DDLogError("Could not determine mount point. No 'potentially-mountable' field in: \(diskImageInfo)")
        return nil
    }

    // Returns an NSDictionary with the contents of the system-entities
    private func parseDiskImageInfo(_ hdiutilOutput: String) -> [[String: Any]] {
        var errorDescription: String? = nil
        var systemEntries = [[String: Any]]()

        if let diskImageRawData = hdiutilOutput.data(using: .utf8) {
            var diskInfoDictionary = [String: Any]()
            do {
                if let potentialDictionary = try PropertyListSerialization.propertyList(from: diskImageRawData, options: [], format: nil) as? [String: Any] {
                    diskInfoDictionary = potentialDictionary
                } else {
                    errorDescription = "Output did not contain valid disk info. \n \(hdiutilOutput)"
                }

            } catch let error as NSError {
                errorDescription = error.localizedDescription
            }

            if let potentialSystemEntries = diskInfoDictionary["system-entities"] as? [[String: Any]] {
                systemEntries = potentialSystemEntries
            } else {
                errorDescription = "Output did not contain a system-entities field or the disk info data was invalid. \n \(diskInfoDictionary)"
            }
        } else {
            errorDescription = "Output was invalid: \n \(hdiutilOutput)"
        }

        if let errorDescriptionString = errorDescription {
            DDLogError("Could not parse disk image info: \(errorDescriptionString)")
        }

        return systemEntries
    }

    private func createMountedDiskFromDiskImage(mountPath: String, disk: Disk, returnCompletion: @escaping (MountedDisk) -> ()) {
        DispatchQueue.main.async {
            DiskUtility.shared.getRawDiskInfo(path: mountPath, returnCompletion: { (potentialDiskInfo) in
                if let diskInfo = potentialDiskInfo {
                    let newMountedDisk = MountedDisk(existingDisk: disk, matchedDiskOutput: diskInfo)
                    disk.mountedDisk = newMountedDisk
                    DDLogInfo("MountedDisk created: \n \(disk.description)")
                    returnCompletion(newMountedDisk)
                }
            })
        }
    }

}
