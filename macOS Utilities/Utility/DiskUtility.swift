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
    private var cachedDisks = [Disk]()
    private var mountedShares = [Disk]()
    private var mountedInstallers = [Disk]()
    private var fakeDisks = [Disk]()

    public var allSharesAndInstallersUnmounted: Bool {
        return self.mountedShares.count == 0 && self.mountedInstallers.count == 0
    }

    private let diskModificationQueue = DispatchQueue(label: "NSDiskModificationQueue")

    private override init() {
        DDLogInfo("Disk Utility Instance Created")
    }

    func presentedSubitemDidChange(at url: URL) {
        let pathExtension = url.pathExtension

        if pathExtension == "dmg" {
            let diskImagesPath = url.deletingLastPathComponent().absoluteString
            DDLogInfo("Potential installer added at: \(diskImagesPath)")
            self.mountDiskImagesAt(diskImagesPath)
        }
    }

    public func getAllDisks() {
        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["list", "-plist"]) { (output) in
            if let plistOutput = output {
                let diskImageInfo = self.parseDiskUtilList(plistOutput)
                if let allDisks = diskImageInfo["AllDisksAndPartitions"] as? [NSDictionary] {
                    self.cachedDisks = allDisks.map { Disk(diskDictionary: $0) }
                    self.mountedInstallers = self.cachedDisks.filter { $0.getMainVolume() !== nil && $0.getMainVolume()?.containsInstaller == true }

                    #if DEBUG
                        self.addFakeDisk()
                    #endif
                }
            }
        }
    }

    public func addFakeDisk() {
        let fakeDisk = Disk(isFakeDisk: true)
        fakeDisks.append(fakeDisk)
    }

    public func mountNFSShare(shareURL: String, localPath: String, didSucceed: @escaping (Bool) -> ()) {
        self.createMountPath(localPath) { (alreadyExisted) in

            let contents = try! FileManager.default.contentsOfDirectory(atPath: localPath)

            if (alreadyExisted == true && (contents.filter { $0.contains(".dmg") }).count > 0) {
                // NFS mount already exists AND has our DMGs
                didSucceed(true)
                return
            }


            TaskHandler.createTask(command: "/sbin/mount", arguments: ["-t", "nfs", shareURL, localPath], timeout: TimeInterval(floatLiteral: 3.0)) { (taskOutput) in
                DDLogInfo("Mount output: \(taskOutput ?? "NO output")")
                if let mountOutput = taskOutput {
                    self.presentedItemURL = URL(fileURLWithPath: localPath, isDirectory: true)
                    if (!["can't", "denied", "error", "killed"].map { mountOutput.contains($0) }.contains(true)) {
                        let nfsShare = Disk(deviceIdentifier: "NFS", content: "NFS", mountPoint: localPath)
                        DDLogInfo("Share mounted: \(nfsShare)")
                        self.mountedShares.append(nfsShare)
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
                    let diskImagePath = "\(folderURL.absolutePath)"
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
                if let plistOutput = taskOutput {
                    let diskImageInfo = self.parseDiskUtilList(plistOutput)
                    self.diskModificationQueue.sync {
                        let diskImage = Disk(diskImageDictionary: diskImageInfo)
                        self.cachedDisks.append(diskImage)
                    }
                }
            }
        }
    }

    private func unmountNFSShare(_ share: Disk?, path: String? = nil, didComplete: @escaping (Bool) -> ()) {
        var validPath = ""

        if let validShare = share {
            validPath = validShare.getMainVolume()!.mountPoint
        }

        if let validSharePath = path {
            validPath = validSharePath
        }

        TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["unmount", validPath], printStandardOutput: true, returnEscaping: { (taskOutput) in
            if let diskUtilOutput = taskOutput {
                if diskUtilOutput.contains("Unmount successful for") {
                    self.mountedShares.removeAll { $0 == share }
                    DDLogInfo("Unmounted share: \(validPath)")
                    didComplete(true)
                    return
                } else {
                    DDLogError("Unable to unmount share \(validPath): \(diskUtilOutput)")
                    DDLogError(diskUtilOutput)
                    didComplete(false)
                    return
                }
            }
        })
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

    public func erase(_ volume: Volume, newName: String, returnCompletion: @escaping (Bool) -> ()) {
        // TODO: check for APFS container
        if(volume.parentDisk.isFakeDisk) {
            DDLogInfo("Starting demo erase on FakeVolume: \(volume)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                DDLogInfo("Finished demo erase on FakeVolume: \(volume)")
                returnCompletion(true)
            }
        } else {
            if(volume.containsInstaller == true) {
                DDLogError("Cannot erase a drive containing an installer")
                returnCompletion(false)
                return
            }

            let devEntry = volume.parentDisk.deviceIdentifier

            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eraseDisk", "APFS", newName, devEntry]) { (taskOutput) in
                if let eraseOutput = taskOutput {
                    DDLogInfo(eraseOutput)
                    returnCompletion(eraseOutput.contains("Finished erase"))
                } else {
                    returnCompletion(false)
                }
            }
        }
    }


    public func ejectAll(didComplete: @escaping (Bool) -> ()) {
        mountedShares = self.cachedDisks.filter { $0.content == "NFS" }
        mountedInstallers = self.cachedDisks.filter { $0.getMainVolume()?.containsInstaller == true }

        if(allSharesAndInstallersUnmounted) {
            didComplete(true)
        }

        mountedInstallers.forEach {
            let currentDisk = $0

            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eject", $0.deviceIdentifier], returnEscaping: { (taskOutput) in
                if let diskUtilOutput = taskOutput {
                    if diskUtilOutput.contains("ejected") {
                        self.diskModificationQueue.sync {
                            self.mountedInstallers.removeAll { $0 == currentDisk }
                            DDLogInfo("Ejected disk image: \(currentDisk.deviceIdentifier) \(diskUtilOutput)")
                            if(self.mountedInstallers.count == 0) {
                                // FIXME:
                                //   NotificationCenter.default.post(name: ItemRepository.refreshRepository, object: nil)
                                DDLogInfo("Unmounting NFS shares now")
                                if self.mountedShares.count > 0 {
                                    for share in self.mountedShares {
                                        self.unmountNFSShare(share, didComplete: { (nfsComplete) in
                                            didComplete(nfsComplete)
                                        })
                                    }
                                } else {
                                    didComplete(true)
                                }
                            }
                        }
                    } else {
                        didComplete(true)
                        DDLogError("Unable to eject disk image: \(currentDisk.deviceIdentifier) \(diskUtilOutput)")
                    }
                }
            })
        }
    }

    public func diskIsAPFS( _ disk: Disk, completion: @escaping (NSDictionary?) -> ()) {
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
}
