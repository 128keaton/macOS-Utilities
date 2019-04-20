//
//  DiskUtility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class DiskUtility: NSObject, NSFilePresenter {
    var presentedItemURL: URL?
    var presentedItemOperationQueue: OperationQueue = OperationQueue.main

    public static let shared = DiskUtility()
    public static let bootDiskAvailable = Notification.Name("NSBootDiskAvailable")

    // MARK: Cached properties
    private var cachedDisks = [Disk]() {
        didSet{
            NotificationCenter.default.post(name: DiskUtility.newDisks, object: nil)
        }
    }
    
    private var cachedShares = [Share](){
        didSet{
            NotificationCenter.default.post(name: DiskUtility.newShares, object: nil)
        }
    }
    
    private var cachedDiskImages = [DiskImage]() {
        didSet{
            NotificationCenter.default.post(name: DiskUtility.newShares, object: nil)
        }
    }
    
    private var cachedFakeDisks = [Disk]() {
        didSet{
            NotificationCenter.default.post(name: DiskUtility.newDisks, object: nil)
        }
    }
    
    private var cachedInstallers = [Installer]()
    
    // MARK: Notifications
    static let newDisks = Notification.Name("NSNewDisks")
    static let newDiskImages = Notification.Name("NSNewDiskImage")
    static let newShares = Notification.Name("NSNewShares")

    public var allSharesAndInstallersUnmounted: Bool {
        return self.cachedShares.count == 0 && self.cachedDiskImages.count == 0
    }

    private let diskModificationQueue = DispatchQueue(label: "NSDiskModificationQueue")

    private override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        DDLogInfo("Disk Utility Instance Created")
    }

    public func getAllDisks() {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["list", "-plist"]) { (output) in
            if let plistOutput = output,
                let plistData = plistOutput.data(using: .utf8) {
                do {
                    let diskUtilityOutput = try PropertyListDecoder().decode(DiskUtilOutput.self, from: plistData)
                    if let allDisks = diskUtilityOutput.allDisksAndPartitions {
                        self.cachedDisks = allDisks
                        self.cachedDisks.forEach {
                            $0.partitions.forEach {
                                $0.scanForInstaller()
                            }
                        }

                        #if DEBUG
                            self.addDisk(self.generateFakeDisk(withPartition: true))
                            self.addDisk(self.generateFakeDisk(withPartition: false))
                        #endif

                        if let bootDisk = self.bootDisk {
                            NotificationCenter.default.post(name: DiskUtility.bootDiskAvailable, object: bootDisk)
                        }
                    }
                } catch {
                    DDLogError("Error parsing diskutil output: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Used for fake disks and other manual disks
    public func addDisk(_ disk: Disk) {
        self.cachedDisks.append(disk)
    }

    // Gets the bootable or "first" disk installed on the machine
    public var bootDisk: Disk? {
        let path = "/"
        let mountPoint = path.cString(using: .utf8)! as [Int8]
        var unsafeMountPoint = mountPoint.map { UInt8(bitPattern: $0) }

        if let fileURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, &unsafeMountPoint, Int(strlen(mountPoint)), true),
            let daSession = DASessionCreate(kCFAllocatorDefault),
            let daDisk = DADiskCreateFromVolumePath(kCFAllocatorDefault, daSession, fileURL) {
            if let description = DADiskCopyDescription(daDisk) {
                if let volumeName = (description as NSDictionary)[kDADiskDescriptionVolumeNameKey] as? String {
                    if let disk = (self.cachedDisks.first { ($0).volumeName == volumeName }) {
                        return disk
                    }
                }
            }
        }
        return nil
    }

    public func generateFakeDisk(withPartition: Bool = false) -> Disk {
        var fakeDiskPartitions = [Partition]()
        if withPartition {
            fakeDiskPartitions.append(Partition(content: "FakePartition-\(String.random(5, numericOnly: true))", deviceIdentifier: "FakePartition-\(String.random(5, numericOnly: true))", diskUUID: String.random(12), rawSize: Units(gigabytes: 500).bytes, rawVolumeName: "FakePartition-\(String.random(5, numericOnly: true))", volumeUUID: String.random(12), mountPoint: "/Volumes/FakePartition-\(String.random(5, numericOnly: true))", isFake: true))
        }

        let fakeDiskIdent = "FakeDisk-\(String.random(5, numericOnly: true))"
        let fakeDiskSize = Units(gigabytes: 500).bytes
        return Disk(rawContent: fakeDiskIdent, deviceIdentifier: fakeDiskIdent, regularPartitions: fakeDiskPartitions, apfsPartitions: nil, rawSize: fakeDiskSize, isFake: true)
    }

    public func updateDiskPartitions(_ disk: Disk, newPartitions: [Partition], isAPFSPartitions: Bool = false) -> Disk? {
        var newDisk: Disk? = nil
        self.cachedDisks.removeAll { $0 == disk }
        do {
            newDisk = try Disk.copy(disk, regularPartitions: newPartitions)
            self.cachedDisks.append(newDisk!)
        } catch {
            DDLogError("Could not update disk partitions: \(error.localizedDescription)")
        }
        return newDisk
    }

    public func addPartitionToDisk(_ disk: Disk, mountPoint: String, volumeName: String, isAPFSPartition: Bool = false) -> Disk? {
        let newPartition = Partition(content: nil, deviceIdentifier: "\(disk.deviceIdentifier)s2", diskUUID: nil, rawSize: disk.rawSize, rawVolumeName: volumeName, volumeUUID: nil, mountPoint: mountPoint, isFake: disk.isFake)
        return self.updateDiskPartitions(disk, newPartitions: [newPartition], isAPFSPartitions: isAPFSPartition)
    }

    public func mountNFSShare(shareURL: String, localPath: String, didSucceed: @escaping (Bool) -> ()) {
        self.createMountPath(localPath) { (alreadyExisted) in

            let contents = try! FileManager.default.contentsOfDirectory(atPath: localPath)

            if (alreadyExisted == true && (contents.filter { $0.contains(".dmg") }).count > 0) {
                // NFS mount already exists AND has our DMGs
                let newShare = Share(type: "NFS", mountPoint: localPath)
                DDLogVerbose("Adding existing share: \(newShare)")
                self.cachedShares.append(newShare)
                didSucceed(true)
                return
            }

            TaskHandler.createTask(command: "/sbin/mount", arguments: ["-t", "nfs", shareURL, localPath], timeout: TimeInterval(floatLiteral: 3.0)) { (taskOutput) in
                DDLogVerbose("Mount output: \(taskOutput ?? "NO output")")
                if let mountOutput = taskOutput {
                    self.presentedItemURL = URL(fileURLWithPath: localPath, isDirectory: true)
                    if (!["can't", "denied", "error", "killed"].map { mountOutput.contains($0) }.contains(true)) {
                        let newShare = Share(type: "NFS", mountPoint: localPath)
                        DDLogVerbose("Creating new share from mount: \(newShare)")
                        self.cachedShares.append(newShare)
                        didSucceed(true)
                    } else {
                        if(mountOutput.contains("killed")) {
                            DDLogError("Mounting NFS share \"\(shareURL) @ \(localPath)\" failed. \n \n Try checking the hostname/path or local mount point.")
                        } else {
                            DDLogError("Mounting NFS share \"\(shareURL):\(localPath)\" failed: \(mountOutput)")
                        }
                        didSucceed(false)
                    }
                }
            }
        }
    }

    private func createMountPath(_ path: String, didExist: @escaping (Bool) -> ()) {
        let temporaryPathURL = URL(fileURLWithPath: path)
        // Checks to see if the temporary dir is created
        if(temporaryPathURL.filestatus == .isNot) {
            TaskHandler.createTask(command: "/bin/mkdir", arguments: [path]) { (taskOutput) in
                if let mkdirOutput = taskOutput {
                    if mkdirOutput.contains("File exists") {
                        didExist(true)
                        return
                    } else {
                        didExist(false)
                        return
                    }
                } else {
                    didExist(false)
                    return
                }
            }
        } else {
            didExist(true)
            DDLogInfo("Temporary path \(path) already exists.")
        }
    }

    public func mountDiskImagesAt(_ folderPath: String) {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            for file in (fileURLs.filter { $0.pathExtension == "dmg" }) {
                let fileName = file.lastPathComponent
                if(fileName.contains(".dmg")) {
                    let diskImagePath = "\(file.absolutePath)"
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
        if(!at.contains(".dmg")) {
            DDLogError("Disk \(at) is not a disk image or is not mountable")
        }

        TaskHandler.createTask(command: "/usr/bin/hdiutil", arguments: ["mount", "-plist", "\(at)", "-noverify"]) { (taskOutput) in
            DDLogInfo("Mounting \(at)")

            if((taskOutput?.contains("hdiutil: mount failed"))!) {
                DDLogError("Disk \(at) could not be mounted: \(taskOutput ?? "No output from hdiutil")")
            } else {
                if let plistOutput = taskOutput,
                    let plistData = plistOutput.data(using: .utf8) {
                    var hdiUtilOutput: HDIUtilOutput? = nil
                    do {
                        hdiUtilOutput = try PropertyListDecoder().decode(HDIUtilOutput.self, from: plistData)
                    } catch {
                        DDLogError("Could not mount disk image at :\(at)")
                    }

                    if let validOutput = hdiUtilOutput,
                        let mountableDiskImage = (validOutput.systemEntities.first { $0.potentiallyMountable == true }) {
                        DDLogVerbose("New Disk Image: \(mountableDiskImage)")
                        self.diskModificationQueue.sync {
                            self.cachedDiskImages.append(mountableDiskImage)
                        }
                    }
                }
            }
        }
    }

    private func removeMountPoint(_ path: String, didComplete: @escaping (Bool) -> ()) {
        TaskHandler.createTask(command: "/bin/rm", arguments: ["-rf", path], printStandardOutput: true, returnEscaping: { (taskOutput) in
            if let rmOutput = taskOutput {
                DDLogError("Error removing \(path): \(rmOutput)")
                didComplete(false)
            } else {
                DDLogInfo("Successfully removed \(path)")
                didComplete(true)
            }
        })
    }

    public func erase(_ partition: Partition, newName: String? = nil, forInstaller: Installer? = nil, returnCompletion: @escaping (Bool, String?) -> ()) {
        var format = "APFS"
        var partitionName = "Macintosh HD"

        if let newPartitionName = newName {
            partitionName = newPartitionName
        }

        if let installer = forInstaller {
            if installer.versionNumber <= 10.13 {
                format = "JHFS+"
            }
        }

        if partition.isFake {
            DDLogInfo("Starting demo erase on fake partition: \(partition)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DDLogInfo("Finished demo erase on fake partition: \(partition)")
                returnCompletion(true, partition.volumeName)
            }
        } else if partition.containsInstaller == false {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eraseVolume", format, partitionName, partition.volumeName]) { (taskOutput) in
                if let eraseOutput = taskOutput {
                    DDLogInfo(eraseOutput)
                    returnCompletion(eraseOutput.contains("Finished erase"), partitionName)
                } else {
                    returnCompletion(false, nil)
                }
            }
        } else {
            DDLogError("Cannot erase a partition containing an installer")
            returnCompletion(false, nil)
        }
    }

    public func erase(_ disk: Disk, newName: String? = nil, forInstaller: Installer? = nil, returnCompletion: @escaping (Bool, String?) -> ()) {
        var format = "APFS"
        var diskName = "Macintosh HD"

        if let newDiskName = newName {
            diskName = newDiskName
        }

        if let installer = forInstaller {
            if installer.versionNumber <= 10.13 {
                format = "JHFS+"
            }
        }

        if disk.isFake {
            DDLogInfo("Starting demo erase on fake disk: \(disk)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DDLogInfo("Finished demo erase on fake disk: \(disk)")
                var fakeDiskPartitions = [Partition]()
                fakeDiskPartitions.append(Partition(content: "FakePartition-\(String.random(5, numericOnly: true))", deviceIdentifier: "FakePartition-\(String.random(5, numericOnly: true))", diskUUID: String.random(12), rawSize: Units(gigabytes: 500).bytes, rawVolumeName: "FakePartition-\(String.random(5, numericOnly: true))", volumeUUID: String.random(12), mountPoint: "/Volumes/FakePartition-\(String.random(5, numericOnly: true))", isFake: true))
                if let updatedDisk = self.updateDiskPartitions(disk, newPartitions: fakeDiskPartitions) {
                    returnCompletion(true, updatedDisk.volumeName)
                }
            }
        } else {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eraseDisk", format, diskName, disk.deviceIdentifier]) { (taskOutput) in
                if let eraseOutput = taskOutput {
                    DDLogInfo(eraseOutput)
                    // MARK: beta..might break
                    // TODO: fix issues that arise with this..since I'm S M R T smart
                    if let updatedDisk = self.addPartitionToDisk(disk, mountPoint: "/Volumes/\(diskName)", volumeName: diskName) {
                        returnCompletion(eraseOutput.contains("Finished erase"), updatedDisk.installablePartition?.volumeName)
                    }
                } else {
                    returnCompletion(false, nil)
                }
            }
        }
    }

    public static func diskIsFormattedFor(_ disk: Disk, installer: Installer) -> Bool {
        if installer.versionNumber >= 10.13 {
            if disk.apfsPartitions != nil {
                return true
            }
        } else {
            return (disk.content == "GUID_partition_scheme")
        }
        return false
    }

    public static func partitionIsFormattedFor(_ partition: Partition, installer: Installer) -> Bool {
        if installer.versionNumber >= 10.13 {
            return partition.isAPFS
        } else if let content = partition.content {
            return content == "Apple_HFS"
        }
        return false
    }

    public var installableDisksWithPartitions: [FileSystemItem] {
        var returnedData = [FileSystemItem]()
        self.cachedDisks.filter { $0.installablePartition != nil }.forEach {
            returnedData.append($0)
            returnedData.append(contentsOf: $0.partitions.filter { $0.installable })
        }

        return returnedData
    }

    public var allDisksWithPartitions: [FileSystemItem] {
        var returnedData = [FileSystemItem]()
        self.cachedDisks.forEach {
            returnedData.append($0)
            returnedData.append(contentsOf: $0.partitions)
        }

        return returnedData
    }

    public var mountedDiskswithPartitions: [FileSystemItem] {
        var returnedData = [FileSystemItem]()
        self.cachedDisks.forEach {
            returnedData.append($0)
            returnedData.append(contentsOf: $0.partitions.filter { $0.isMounted })
        }

        return returnedData
    }

    public func ejectAll(didComplete: @escaping (Bool) -> ()) {
        if(allSharesAndInstallersUnmounted) {
            didComplete(true)
        }

        self.ejectAllDiskImages { (allDiskImagesEjected) in
            self.ejectAllShares(didComplete: { (allSharesCompleted) in
                didComplete(allDiskImagesEjected && allDiskImagesEjected)
            })
        }
    }

    public func ejectAllDiskImages(didComplete: @escaping (Bool) -> ()) {
        if(allSharesAndInstallersUnmounted) {
            didComplete(true)
        }
        
        DDLogVerbose("Ejecting disk images: \(self.cachedDiskImages)")
        self.cachedDiskImages.forEach {
            let currentDisk = $0
            DDLogVerbose("Ejecting disk image: \(currentDisk)")
            if let deviceIdentifier = currentDisk.devEntry {
                TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eject", deviceIdentifier], returnEscaping: { (taskOutput) in
                    if let diskUtilOutput = taskOutput {
                        if diskUtilOutput.contains("ejected") {
                            self.diskModificationQueue.sync {
                                DDLogVerbose("Ejected disk image: \(currentDisk)")
                                self.cachedDiskImages.removeAll { $0 == currentDisk }
                                self.cachedDiskImages.removeAll { $0.isMounted == false }
                                if self.cachedDiskImages.count == 0 {
                                    didComplete(true)
                                }
                            }
                        } else {
                            DDLogError("Unable to eject disk image: \(deviceIdentifier) \(diskUtilOutput)")
                        }
                    }
                })
            }
        }
        if self.cachedDiskImages.count == 0 {
            didComplete(true)
        }
    }

    public func ejectAllShares(didComplete: @escaping (Bool) -> ()) {
        if(allSharesAndInstallersUnmounted) {
            didComplete(true)
        }

        self.cachedShares.forEach {
            let currentShare = $0
            if let mountPoint = currentShare.mountPoint {
                TaskHandler.createTask(command: "/sbin/umount", arguments: [mountPoint], returnEscaping: { (taskOutput) in
                    self.diskModificationQueue.sync {
                        self.cachedShares.removeAll { $0 == currentShare }
                        if self.cachedShares.count == 0 {
                            didComplete(true)
                        }
                    }
                })
            }
        }
    }

    public func diskIsAPFS(_ disk: Disk, completion: @escaping (NSDictionary?) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["apfs", "list", "-plist", disk.deviceIdentifier], hideTaskFailed: true) { (output) in
            if let apfsOutput = output {
                if !apfsOutput.contains("is not an APFS Container") {
                    completion(self.parseDiskUtilAPFSList(apfsOutput))
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
                    errorDescription = "Output did not contain valid diskutil info. \n \(diskUtilOutput)"
                }

            } catch let error as NSError {
                errorDescription = error.localizedDescription
            }
        } else {
            errorDescription = "diskutil output was invalid: \n \(diskUtilOutput)"
        }

        if let errorDescriptionString = errorDescription {
            DDLogError("Could not parse diskutil info: \(errorDescriptionString)")
        }

        return validDictionary
    }

    private func parseDiskUtilAPFSList(_ apfsOutput: String) -> NSDictionary {
        var errorDescription: String? = nil
        var validDictionary = NSDictionary()

        if let diskImageRawData = apfsOutput.data(using: .utf8) {
            do {
                if let potentialDictionary = try PropertyListSerialization.propertyList(from: diskImageRawData, options: [], format: nil) as? NSDictionary {
                    validDictionary = potentialDictionary
                } else {
                    errorDescription = "Output did not contain valid APFS disk info. \n \(apfsOutput)"
                }

            } catch let error as NSError {
                errorDescription = error.localizedDescription
            }
        } else {
            errorDescription = "APFS output was invalid: \n \(apfsOutput)"
        }

        if let errorDescriptionString = errorDescription {
            DDLogError("Could not parse APFS disk info: \(errorDescriptionString) \(apfsOutput)")
        }

        return validDictionary
    }

    private func parseDiskImageInfo(_ hdiutilOutput: String) -> NSDictionary {
        var errorDescription: String? = nil
        var validDictionary = NSDictionary()

        if let diskImageRawData = hdiutilOutput.data(using: .utf8) {
            do {
                if let potentialDictionary = try PropertyListSerialization.propertyList(from: diskImageRawData, options: [], format: nil) as? NSDictionary {
                    validDictionary = potentialDictionary
                } else {
                    errorDescription = "Output did not contain valid hdiutil image info. \n \(hdiutilOutput)"
                }

            } catch let error as NSError {
                errorDescription = error.localizedDescription
            }
        } else {
            errorDescription = "hdiutil output was invalid: \n \(hdiutilOutput)"
        }

        if let errorDescriptionString = errorDescription {
            DDLogError("Could not parse hdiutil info: \(errorDescriptionString)")
        }

        return validDictionary
    }


    @objc func didMount(_ notification: NSNotification) {
        if let volumePath = notification.userInfo!["NSDevicePath"] as? String,
            let installAppName = notification.userInfo!["NSWorkspaceVolumeLocalizedNameKey"] as? String {
            if (volumePath.contains("Install macOS") || volumePath.contains("Install OS X")) {
                let newInstaller = Installer(volumePath: volumePath, mountPoint: volumePath.fileURL, appName: installAppName)
                self.cachedInstallers.append(newInstaller)
            }
        }
    }
}
