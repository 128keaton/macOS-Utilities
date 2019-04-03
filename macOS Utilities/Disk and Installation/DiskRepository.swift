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

    private let diskUtility = DiskUtility.shared
    public var delegate: DiskRepositoryDelegate? = nil

    private init() {
        registerForNotifications()
        diskUtility.getAllDisks(mountedOnly: true) { (collectedDisks) in
            DDLogInfo("Finished collecting disks")
            self.mountedDisks = collectedDisks
            self.sortMountedDisks()
        }
    }

    private func sortMountedDisks(){
        diskImages = mountedDisks.filter{ $0.diskType == .dmg }
        physicalDisks = mountedDisks.filter{ $0.diskType == .physical }
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
    
    public func getInstallableDisks() -> [Disk]{
        return physicalDisks.filter { $0.mountedDisk !== nil && $0.mountedDisk?.isInstallable == true }
    }

    public func getInstallers(returnCompletion: @escaping ([Installer]) -> ()){
        diskUtility.getAllDisks { (allDisks) in
            returnCompletion(allDisks.filter {$0.mountedDisk != nil && $0.mountedDisk?.containsInstaller == true}.map { $0.mountedDisk!.installer! })
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
                    let newDisk =  Disk(diskType: .dmg, isRemoteDisk: false, path: diskImagePath, mountPath: nil)
                    diskUtility.mount(disk: newDisk) { (mountedDisk) in
                        
                    }
                } else {
                    DDLogError("\(fileName) is not a valid DMG")
                }
            }
        } catch {
            DDLogError("Unable to list directory: \(folderURL)")
        }
    }

    private func mountNFS(disk: Disk, returnCompletion: @escaping (MountedDisk) -> ()) {
        if(disk.mountPath != nil && createMountPath(path: disk.mountPath!)) {
            TaskHandler.createTask(command: "/sbin/mount", arguments: ["-t", "nfs", "-o", "soft,intr,rsize=8192,wsize=8192,timeo=900,retrans=3,proto=tcp", disk.path!, disk.mountPath!]) { (taskOutput) in
                if let mountOutput = taskOutput {
                    let badErrorWords = ["can't", "denied", "error"].flatMap { $0.components(separatedBy: " ") }
                    if(badErrorWords.filter { mountOutput.range(of: $0) != nil }.count != 0) {
                        DDLogError("Disk \(disk.path ?? "No path") could not be mounted: \n")
                        DDLogError(mountOutput)
                    } else {
                        self.waitForVolume(path: disk.path!)
                        DDLogError("Disk \(disk.path ?? "No path") has been mounted")
                        DDLogInfo(disk.description)
                    }
                } else {
                    DDLogError("Disk \(disk.path ?? "No path") does not contain a valid mountpoint.")
                }
            }
        }
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
