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

    public static var forceFusionDrive = false
    public static let shared = DiskUtility()

    // MARK: Cached properties
    private static var cachedDisks = [Disk]() {
        didSet {
            NotificationCenter.default.post(name: GlobalNotifications.newDisks, object: nil)
        }
    }

    private static var cachedShares = [Share]() {
        didSet {
            NotificationCenter.default.post(name: GlobalNotifications.newShares, object: nil)
        }
    }

    public static var allSharesAndInstallersUnmounted: Bool {
        return self.cachedShares.count == 0 && HardDriveImageUtility.allImagesUnmounted
    }

    private static let diskModificationQueue = DispatchQueue(label: "NSDiskModificationQueue")

    private override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
        DDLogInfo("Disk Utility Instance Created")
    }

    public static func getAllDisks() {
        #if DEBUG
            self.addDisk(self.generateFakeDisk(withPartition: true))
            self.addDisk(self.generateFakeDisk(withPartition: false))
        #endif

        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["list", "-plist"]) { (output) in
            if let listOutput = output {
                do {
                    let diskUtilityList: DiskUtilityList = try OutputParser().parseOutput(listOutput, toolType: OutputToolType.diskUtility, outputType: OutputType.list)
                    diskUtilityList.disks.forEach {
                        self.addDisk($0)
                    }
                } catch {
                    DDLogError("Error parsing Disk Utility output: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Used for fake disks and other manual disks
    public static func addDisk(_ disk: Disk) {
        cachedDisks.append(disk)
    }

    /// Gets the bootable or "first" disk installed on the machine
    public static var bootDisk: Disk? {
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

    public static var hasFusionDrive: Bool {
        if (forceFusionDrive) {
            return true
        }

        if !(Sysctl.model.contains("iMac") || Sysctl.model.contains("Macmini")) {
            DDLogVerbose("A \(Sysctl.model) will never contain a Fusion Drive.")
            return false
        }

        let disks = DiskUtility.allDisksWithPartitions.filter { $0.itemType == .disk } as! [Disk]
        let disksWithInfo = disks.filter { $0.info != nil }
        let disksPotentiallyFusionParts = disksWithInfo.filter { $0.info!.potentialFusionDriveHalve }

        if disksPotentiallyFusionParts.count <= 1 {
            DDLogVerbose("Internal Drives: \(disksPotentiallyFusionParts)")
            DDLogVerbose("The reported number of internal drives (\(disksPotentiallyFusionParts.count)) was less than two, therefore no Fusion Drive.")
            return false
        }

        if (disksWithInfo.filter { $0.info!.isSolidState == true }).count == 0 {
            DDLogVerbose("There weren't any non-hard disk drives, therefore no Fusion Drive.")
            return false
        }

        // Check for an HDD
        if (disksWithInfo.filter { $0.info!.isSolidState == false }).count == 0 {
            DDLogVerbose("There weren't any non-solid state drives, therefore no Fusion Drive.")
            return false
        }

        return true
    }

    private static func generateFakeDisk(withPartition: Bool = false) -> Disk {
        var fakeDiskPartitions = [Partition]()
        if withPartition {
            fakeDiskPartitions.append(Partition(content: "FakePartition-\(String.random(5, numericOnly: true))", deviceIdentifier: "FakePartition-\(String.random(5, numericOnly: true))", diskUUID: String.random(12), rawSize: Units(gigabytes: 500).bytes, rawVolumeName: "FakePartition-\(String.random(5, numericOnly: true))", volumeUUID: String.random(12), mountPoint: "/Volumes/FakePartition-\(String.random(5, numericOnly: true))", isFake: true))
        }

        let fakeDiskIdent = "FakeDisk-\(String.random(5, numericOnly: true))"
        let fakeDiskSize = Units(gigabytes: 500).bytes
        return Disk(rawContent: fakeDiskIdent, deviceIdentifier: fakeDiskIdent, regularPartitions: fakeDiskPartitions, apfsPartitions: nil, rawSize: fakeDiskSize, isFake: true, info: nil)
    }

    private static func updateDiskPartitions(_ disk: Disk, newPartitions: [Partition], isAPFSPartitions: Bool = false) -> Disk? {
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

    private static func addPartitionToDisk(_ disk: Disk, mountPoint: String, volumeName: String, isAPFSPartition: Bool = false) -> Disk? {
        let newPartition = Partition(content: nil, deviceIdentifier: "\(disk.deviceIdentifier)s2", diskUUID: nil, rawSize: disk.rawSize, rawVolumeName: volumeName, volumeUUID: nil, mountPoint: mountPoint, isFake: disk.isFake)
        return self.updateDiskPartitions(disk, newPartitions: [newPartition], isAPFSPartitions: isAPFSPartition)
    }

    public static func mountNFSShare(shareURL: String, localPath: String, didSucceed: @escaping (Bool) -> ()) {
        self.createMountPath(localPath) { (alreadyExisted) in

            let contents = try! FileManager.default.contentsOfDirectory(atPath: localPath)

            if (alreadyExisted == true && (contents.filter { $0.contains(".dmg") }).count > 0) {
                // NFS mount already exists AND has our DMGs
                let newShare = Share(type: "NFS", mountPoint: localPath)
                DDLogVerbose("Adding existing share: \(newShare.mountPoint ?? "No mount point")")
                self.cachedShares.append(newShare)
                didSucceed(true)
                return
            }

            TaskHandler.createTask(command: "/sbin/mount", arguments: ["-t", "nfs", shareURL, localPath], timeout: TimeInterval(floatLiteral: 3.0)) { (taskOutput) in
                if let mountOutput = taskOutput {
                    DiskUtility.shared.presentedItemURL = URL(fileURLWithPath: localPath, isDirectory: true)
                    if (!["can't", "denied", "error", "killed"].map { mountOutput.contains($0) }.contains(true)) {
                        let newShare = Share(type: "NFS", mountPoint: localPath)
                        DDLogVerbose("Creating new share from mount: \(newShare.mountPoint ?? "No mount point")")
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

    private static func createMountPath(_ path: String, didExist: @escaping (Bool) -> ()) {
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


    private static func removeMountPoint(_ path: String, didComplete: @escaping (Bool) -> ()) {
        TaskHandler.createTask(command: "/bin/rm", arguments: ["-rf", path], returnEscaping: { (taskOutput) in
                if let rmOutput = taskOutput {
                    DDLogError("Error removing \(path): \(rmOutput)")
                    didComplete(false)
                } else {
                    DDLogInfo("Successfully removed \(path)")
                    didComplete(true)
                }
            })
    }

    // MARK: CoreStorage/Fusion Drive functions

    /// MARK: Get all of the logical volume groups
    public static func getLogicalVolumeGroups(completion: @escaping ([LogicalVolumeGroup]?) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["cs", "list", "-plist"], returnEscaping: { (output) in
                if let coreStorageListOutput = output {
                    do {
                        let coreStorageList: DiskUtilityCoreStorageList = try OutputParser().parseOutput(coreStorageListOutput, toolType: .diskUtility, outputType: .coreStorageList)
                        completion(coreStorageList.logicalVolumeGroups)
                    } catch {
                        DDLogError("Could not list Core Storage Volumes: \(error)")
                    }
                }
            })
    }

    /// Create a Core Storage volume. Requires the Logical Volume Group UUID to be passed
    public static func createCoreStorageVolume(logicalVolumeGroupUUID: String, completion: @escaping (String, Bool) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["cs", "createVolume", logicalVolumeGroupUUID, "jhfs+", "Macintosh HD", "100%"]) { (output) in
            if let csCreateVolumeOutput = output,
                !csCreateVolumeOutput.contains("Error"),
                csCreateVolumeOutput.contains("Finished CoreStorage operation") {
                completion(csCreateVolumeOutput, true)
            } else if let csCreateVolumeErrorOutput = output {
                completion("Could not create Core Storage Volume: \(csCreateVolumeErrorOutput)", false)
            } else {
                completion("Could not create Core Storage vOlume. No output from 'cs createVolume' command", false)
            }
        }

    }

    public static func createFusionDrive(completion: @escaping (String, Bool) -> ()) {
        guard let firstSSD = (self.cachedDisks.first { $0.info != nil && $0.info!.isSolidState && $0.info!.potentialFusionDriveHalve }) else { return completion("Could not find Solid State Drive", false) }
        guard let firstHDD = (self.cachedDisks.first { $0.info != nil && !$0.info!.isSolidState && $0.info!.potentialFusionDriveHalve }) else { return completion("Could not find Hard Disk Drive", false) }

        var waitToDeleteSemaphore: DispatchSemaphore? = nil

        getLogicalVolumeGroups(completion: { (potentialCoreStorageContainers) in
            if let coreStorageVolumes = potentialCoreStorageContainers {
                waitToDeleteSemaphore = DispatchSemaphore(value: 1)
                coreStorageVolumes.forEach {
                    TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["cs", "delete", $0.containerUUID]) { (output) in
                        DDLogVerbose("Deleted container \(output ?? "")")
                    }
                }
                waitToDeleteSemaphore?.signal()
            }
        })

        if let semaphore = waitToDeleteSemaphore {
            semaphore.wait()
        }

        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["cs", "create", "FusionDrive", firstSSD.deviceIdentifier, firstHDD.deviceIdentifier]) { (output) in
            if let csCreateOutput = output,
                csCreateOutput.contains("Discovered new Logical Volume Group") {
                self.getLogicalVolumeGroups(completion: { (potentialCoreStorageContainers) in
                    if let coreStorageContainers = potentialCoreStorageContainers {
                        if let coreStorageContainer = coreStorageContainers.first {
                            self.createCoreStorageVolume(logicalVolumeGroupUUID: coreStorageContainer.containerUUID, completion: { (message, didCreate) in
                                completion(message, didCreate)
                            })
                        } else {
                            completion("Could not find Core Storage Container in \(coreStorageContainers)", false)
                        }
                    } else {
                        completion("No Core Storage Volumes were returned", false)
                    }
                })
            } else if let csCreateErrorOutput = output {
                completion("Could not create Fusion Drive: \(csCreateErrorOutput)", false)
            } else {
                completion("Could not create Fusion Drive. No output from 'cs create' command", false)
            }
        }
    }

    /// Erase a Disk or Partition, optionally specifying an installer
    public static func erase(_ fileSystemItem: FileSystemItem, newName: String? = nil, forInstaller installer: Installer? = nil, returnCompletion: @escaping (Bool, String?) -> ()) {
        var diskUtilCommand: String? = nil
        var format = "JHFS+"
        var isFake = false
        var containsInstaller = false
        var name: String? = nil
        var itemType: FileSystemItemType = .disk
        var itemIdentifier: String? = nil

        if type(of: fileSystemItem) == Partition.self {
            let itemPartition = fileSystemItem as! Partition

            diskUtilCommand = "eraseVolume"
            itemType = itemPartition.itemType
            containsInstaller = itemPartition.containsInstaller
            name = itemPartition.volumeName
            itemIdentifier = itemPartition.volumeName

            if itemPartition.isFake {
                isFake = true
            }
        } else if type(of: fileSystemItem) == Disk.self {
            let itemDisk = fileSystemItem as! Disk

            diskUtilCommand = "eraseDisk"
            itemType = itemDisk.itemType
            name = itemDisk.volumeName
            itemIdentifier = itemDisk.deviceIdentifier

            if itemDisk.isFake {
                isFake = true
            }
        }

        if let validName = newName {
            name = validName
        }

        if let validInstaller = installer,
            validInstaller.version.needsAPFS {
            DDLogVerbose("Installing High Sierra or greater, must use APFS.")
            if (ProcessInfo().operatingSystemVersion.minorVersion > 12) {
                format = "APFS"
            }
        }

        if let validDiskUtilCommand = diskUtilCommand,
            let validItemName = name,
            let validItemIdentifier = itemIdentifier,
            containsInstaller == false {
            if isFake {
                DDLogInfo("Starting demo erase on fake \(fileSystemItem)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    DDLogInfo("Finished demo erase on fake \(fileSystemItem)")
                    if itemType == .disk {
                        let itemDisk = fileSystemItem as! Disk
                        var fakeDiskPartitions = [Partition]()
                        fakeDiskPartitions.append(Partition(content: "FakePartition-\(String.random(5, numericOnly: true))", deviceIdentifier: "FakePartition-\(String.random(5, numericOnly: true))", diskUUID: String.random(12), rawSize: Units(gigabytes: 500).bytes, rawVolumeName: "FakePartition-\(String.random(5, numericOnly: true))", volumeUUID: String.random(12), mountPoint: "/Volumes/FakePartition-\(String.random(5, numericOnly: true))", isFake: true))
                        if let updatedDisk = self.updateDiskPartitions(itemDisk, newPartitions: fakeDiskPartitions) {
                            returnCompletion(true, updatedDisk.volumeName)
                        }
                    }
                    returnCompletion(true, validItemName)
                }
            } else {
                TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: [validDiskUtilCommand, format, validItemName, validItemIdentifier]) { (taskOutput) in
                    if let eraseOutput = taskOutput,
                        eraseOutput.contains("Finished erase") {
                        if itemType == .disk {
                            let itemDisk = fileSystemItem as! Disk
                            if let updatedDisk = self.addPartitionToDisk(itemDisk, mountPoint: "/Volumes/\(validItemName)", volumeName: validItemName) {
                                returnCompletion(eraseOutput.contains("Finished erase"), updatedDisk.installablePartition?.volumeName)
                            }
                        } else if itemType == .partition {
                            returnCompletion(eraseOutput.contains("Finished erase"), validItemName)
                        }
                    } else {
                        returnCompletion(false, nil)
                    }
                }
            }
        }
    }

    /// Check if a disk is properly formatted for an installer
    public static func diskIsFormattedFor(_ disk: Disk, installer: Installer) -> Bool {
        if installer.version.needsAPFS {
            if disk.apfsPartitions != nil {
                return true
            }
        } else {
            return (disk.content == "GUID_partition_scheme")
        }
        return false
    }

    /// Check if a partition is properly formatted for an installer
    public static func partitionIsFormattedFor(_ partition: Partition, installer: Installer) -> Bool {
        if installer.version.needsAPFS {
            return partition.isAPFS
        } else if let content = partition.content {
            return content == "Apple_HFS"
        }
        return false
    }

    public static var installableDisksWithPartitions: [FileSystemItem] {
        var returnedData = [FileSystemItem]()
        self.cachedDisks.filter { $0.installablePartition != nil }.forEach {
            returnedData.append($0)
            returnedData.append(contentsOf: $0.partitions.filter { $0.installable })
        }

        return returnedData
    }

    public static var allDisksWithPartitions: [FileSystemItem] {
        var returnedData = [FileSystemItem]()
        self.cachedDisks.forEach {
            returnedData.append($0)
            returnedData.append(contentsOf: $0.partitions)
        }

        return returnedData
    }

    public static var mountedDiskswithPartitions: [FileSystemItem] {
        var returnedData = [FileSystemItem]()
        self.cachedDisks.forEach {
            returnedData.append($0)
            returnedData.append(contentsOf: $0.partitions.filter { $0.isMounted })
        }

        return returnedData
    }

    public static func ejectAll(didComplete: @escaping (Bool) -> ()) {
        if(allSharesAndInstallersUnmounted) {
            didComplete(true)
        }

        HardDriveImageUtility.ejectAllDiskImages { (allDiskImagesEjected) in
            self.ejectAllShares(didComplete: { (allSharesEjected) in
                didComplete(allDiskImagesEjected && allSharesEjected)
            })
        }
    }

    public static func ejectAllShares(didComplete: @escaping (Bool) -> ()) {
        if(allSharesAndInstallersUnmounted) {
            didComplete(true)
        }

        self.cachedShares.forEach {
            let currentShare = $0
            if let mountPoint = currentShare.mountPoint {
                TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["unmount", "force", mountPoint], returnEscaping: { (output) in
                        if let unmountOutput = output,
                            (unmountOutput.contains("Unmount successful for") || unmountOutput.contains("Unmount failed for")) {
                            self.cachedShares.removeAll { $0 == currentShare }
                            didComplete(true)
                        }
                    })
            }
        }
    }

    public static func getDiskInfo(_ disk: Disk, update: Bool = false, completion: @escaping (DiskUtilityInfo?) -> ()) {
        if let existingDiskInfo = disk.info,
            !update {
            completion(existingDiskInfo)
        }

        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", "-plist", "/dev/\(disk.deviceIdentifier)"], silent: true) { (output) in
            if let infoOutput = output {
                do {
                    completion(try OutputParser().parseOutput(infoOutput, toolType: .diskUtility, outputType: .info))
                } catch {
                    DDLogError("Could not get disk information for disk \(disk.deviceIdentifier): \(error)")
                    completion(nil)
                }
            }
        }
    }

    @objc func didMount(_ notification: NSNotification) {
        if let volumePath = notification.userInfo!["NSDevicePath"] as? String {
            if (volumePath.contains("Install macOS") || volumePath.contains("Install OS X")) {
                ItemRepository.shared.scanForMountedInstallers()
            } else if !(DiskUtility.cachedDisks.contains { $0.installablePartition?.volumeName == volumePath }) {
                DiskUtility.getAllDisks()
            } else {
                print("Other?")
            }
        }
    }

    @objc func didUnmount(_ notification: NSNotification) {
        if let volumePath = notification.userInfo!["NSDevicePath"] as? String,
            let installAppName = notification.userInfo!["NSWorkspaceVolumeLocalizedNameKey"] as? String {
            if (volumePath.contains("Install macOS") || volumePath.contains("Install OS X")) {
                let installerName = installAppName.replacingOccurrences(of: "Install ", with: "")
                DDLogVerbose("Looking for installer \(installerName) to remove from repository")

                if let foundInstaller = (ItemRepository.shared.installers.first { $0.version.name == installerName }) {
                    ItemRepository.shared.removeFromRepository(itemToRemove: foundInstaller)
                } else {
                    DDLogVerbose("Could not find installer to remove from name: \(installerName)")
                }
            } else if !(DiskUtility.cachedDisks.contains { $0.installablePartition?.volumeName == volumePath }) {
                DiskUtility.getAllDisks()
            }
        }
    }
}
