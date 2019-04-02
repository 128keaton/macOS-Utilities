//
//  DiskRepository.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class DiskRepository {
    public static let shared = DiskRepository()

    private var diskImages = [Disk]()
    private var physicalDisks = [Disk]()
    private var watchedDisks = [String]()

    private var mountedDisks = [Disk]()
    private var installers = [Installer]()

    public var delegate: DiskRepositoryDelegate? = nil

    private init() {
        registerForNotifications()
        getCurrentDisks { (finished) in
            DDLogInfo("Finished collecting disks.")
        }
    }

    public func unmountAll() {
        for disk in diskImages {
            if(disk.isMounted) {
                disk.mountedDisk?.eject()
            }
        }
    }

    public func getDiskImages() -> [Disk] {
        return physicalDisks
    }

    public func getPhysicalDisks() -> [Disk] {
        return physicalDisks
    }

    public func getInstallers() -> [Installer] {
        installers = []
        for disk in diskImages {
            if(disk.mountedDisk != nil && disk.mountedDisk?.installer != nil) {
                installers.append(disk.mountedDisk!.installer!)
            }
        }

        for disk in physicalDisks {
            if(disk.mountedDisk != nil && disk.mountedDisk?.installer != nil) {
                installers.append(disk.mountedDisk!.installer!)
            }
        }

        return installers
    }

    public func getCurrentDisks(returnCompletion: @escaping(Bool) -> ()) {
        DispatchQueue.main.async {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["list"]) { (allDisks) in
                let matchedDisks = allDisks!.matches("([0-9]+( |.[0-9]+ )(GB|TB))+ *disk([0-9]*)s.").map { Disk(diskType: .physical, matchedDiskOutput: $0) }

                self.physicalDisks = []
                self.diskImages = []
                for newDisk in matchedDisks {
                    if(newDisk.mountedDisk?.isValid == true) {
                        if(self.physicalDisks.first(where: { $0.uniqueDiskID == newDisk.uniqueDiskID }) == nil && newDisk.diskType == .physical) {
                            self.physicalDisks.append(newDisk)
                        } else if(self.diskImages.first(where: { $0.uniqueDiskID == newDisk.uniqueDiskID }) == nil && newDisk.diskType == .dmg) {
                            self.diskImages.append(newDisk)
                        }
                    }
                }
                returnCompletion(true)
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
                    Disk(diskType: .dmg, isRemoteDisk: false, path: diskImagePath, mountPath: nil).mount()
                } else {
                    DDLogError("\(fileName) is not a valid DMG")
                }
            }
        } catch {
            DDLogError("Unable to list directory: \(folderURL)")
        }
    }

    public func mount(disk: Disk, returnEscaping: @escaping (MountedDisk?) -> ()) {
        if(disk.isRemoteDisk == true && disk.diskType == .nfs) {
            returnEscaping(self.mountNFS(disk: disk))
        } else if(disk.diskType == .dmg) {
            mountDMG(disk: disk) { (mountedDisk) in
                returnEscaping(mountedDisk)
            }
        } else if(disk.diskType == .physical) {

        }

        returnEscaping(nil)
    }

    private func mountDMG(disk: Disk, returnCompletion: @escaping (MountedDisk?) -> ()) {
        TaskHandler.createTask(command: "/usr/bin/hdiutil", arguments: ["mount", "-plist", "\(disk.path!)", "-noverify"]) { (taskOutput) in
            DDLogInfo("Mounting \(disk.path!)")

            if((taskOutput?.contains("hdiutil: mount failed"))!) {
                DDLogError("Disk \(disk.path ?? "No path") could not be mounted: \n")
                DDLogError(taskOutput!)
                returnCompletion(nil)
            } else {
                if let returnedData = taskOutput?.data(using: .utf8) {
                    let dictionary = try? PropertyListSerialization.propertyList(from: returnedData, options: [], format: nil)
                    if(dictionary != nil) {
                        let firstMountable = ((dictionary as! [String: Any])["system-entities"] as! [[String: Any]]).filter { ($0["potentially-mountable"] as! Int) == 1 }.first!
                        if let mountPath = firstMountable["mount-point"] as? String {
                            let existingDisk = self.diskImages.filter { $0.mountPath == mountPath && $0.mountedDisk !== nil }.first
                            if(existingDisk == nil) {
                                self.createMountDiskFromDMGForDisk(mountPath: mountPath, disk: disk) { (newMountedDisk) in
                                    self.mountedDisks.append(disk)
                                    returnCompletion(newMountedDisk)
                                }
                            } else {
                                DDLogInfo("Disk already mounted: \n \(existingDisk!.description)")
                                returnCompletion(existingDisk!.mountedDisk!)
                            }
                        }
                    }
                }
            }
            returnCompletion(nil)
        }
    }

    private func createMountDiskFromDMGForDisk(mountPath: String, disk: Disk, returnCompletion: @escaping (MountedDisk) -> ()) {
        DispatchQueue.main.async {
            self.getRawDiskInfo(path: mountPath, returnCompletion: { (potentialDiskInfo) in
                if let diskInfo = potentialDiskInfo {
                    let newMountedDisk = MountedDisk(disk: disk, matchedDiskOutput: diskInfo)
                    disk.mountedDisk = newMountedDisk
                    DDLogInfo("Disk now mounted: \n \(disk.description)")
                    returnCompletion(newMountedDisk)
                }
            })
        }
    }

    private func mountNFS(disk: Disk) -> MountedDisk? {
        if(disk.mountPath != nil && createMountPath(path: disk.mountPath!)) {
            /*  if let taskOutput = TaskHandler.createTask(command: "/sbin/mount", arguments: ["-t", "nfs", "-o", "soft,intr,rsize=8192,wsize=8192,timeo=900,retrans=3,proto=tcp", disk.path!, disk.mountPath!]) {
                let badErrorWords = ["can't", "denied", "error"].flatMap { $0.components(separatedBy: " ") }
                if(badErrorWords.filter { taskOutput.range(of: $0) != nil }.count != 0) {
                    DDLogError("Disk \(disk.path ?? "No path") could not be mounted: \n")
                    DDLogError(taskOutput)
                } else {
                    waitForVolume(path: disk.path!)
                    DDLogError("Disk \(disk.path ?? "No path") has been mounted")
                    DDLogInfo(disk.description)
                }
            }*/
        } else {
            DDLogError("Disk \(disk.path ?? "No path") does not contain a valid mountpoint.")
        }

        return nil
    }

    private func createMountPath(path: String) -> Bool {
        let newMountPath = URL(fileURLWithPath: path)

        if(newMountPath.filestatus == .isNot) {
            DDLogInfo("Creating directory at \(path)!)")
            return TaskHandler.createTaskWithStatus(command: "/bin/mkdir", arguments: [path])
        }

        DDLogInfo("Temporary path \(path) already exists.")
        return true
    }


    private func waitForVolume(path: String) {
        watchedDisks.append(path)
    }

    public func getRawDiskInfo(mountedDisk: MountedDisk, returnCompletion: @escaping (String?) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", mountedDisk.mountPoint]) { (diskInfo) in
            returnCompletion(diskInfo)
        }
    }

    public func getRawDiskInfo(path: String, returnCompletion: @escaping (String?) -> ()) {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", path]) { (diskInfo) in
            returnCompletion(diskInfo)
        }
    }

    private func registerForNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    @objc func didMount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            let newDevicePath = devicePath.components(separatedBy: CharacterSet.decimalDigits).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            DDLogInfo("New device incoming: \(newDevicePath)")
        }
    }

    public func installersDidUpdate() {
        delegate?.installersUpdated()
    }

    @objc func didUnmount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            let removedDevicePath = devicePath.components(separatedBy: CharacterSet.decimalDigits).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            diskImages = diskImages.filter { $0.mountPath != removedDevicePath }
            physicalDisks = physicalDisks.filter { $0.mountPath != removedDevicePath }
        }
    }
}

protocol DiskRepositoryDelegate {
    func installersUpdated()
}
