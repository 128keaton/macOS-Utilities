//
//  MountDisk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class MountDisk {
    let temporaryPath = "/var/tmp/Installers/"
    var delegate: MountDiskDelegate? = nil

    private var compatibilityChecker: Compatibility = Compatibility()
    private var host: String
    private var hostPath: String
    private var mountedVersions = [OSVersion]()
    private var mountedVolumes = [String]()

    init(host: String, hostPath: String) {
        self.host = host
        self.hostPath = hostPath
        registerForNotifications()
        mountInstallerServer()
    }

    func getInstallerDiskImages() -> [OSVersion] {
        var diskImages = [OSVersion]()

        let fileManager = FileManager.default
        let installersURL = URL(fileURLWithPath: temporaryPath)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: installersURL, includingPropertiesForKeys: nil)
            for file in fileURLs {
                let fileName = file.lastPathComponent
                if(fileName.contains(".dmg")) {
                    let version = fileName.replacingOccurrences(of: ".dmg", with: "")
                    let label = VersionNumbers.getNameForVersion(version)
                    let diskImagePath = "\(installersURL.absoluteString.replacingOccurrences(of: "file://", with: ""))/\(fileName)"

                    diskImages.append(OSVersion(diskImagePath: diskImagePath, appLabel: label, version: version))
                }
            }
        } catch {
            DDLogError("Error listing the installers: \(error.localizedDescription)")
        }

        return diskImages
    }

    private func createInstallersPath() {
        let temporaryPathURL = URL(fileURLWithPath: temporaryPath)
        // Checks to see if the temporary dir is created
        if(temporaryPathURL.filestatus == .isNot) {
            let taskOutput = handleTask(command: "/bin/mkdir", arguments: [temporaryPath])
            DDLogInfo("Creating directory: /n \(taskOutput!)")
            return
        }

        DDLogInfo("Temporary path \(temporaryPath) already exists.")
    }

    private func mountInstallerServer() {
        createInstallersPath()
        if let taskOutput = handleTask(command: "/sbin/mount", arguments: ["-t", "nfs", "-o", "soft,intr,rsize=8192,wsize=8192,timeo=900,retrans=3,proto=tcp", "\(self.host):\(self.hostPath)", temporaryPath]) {

            let badErrorWords = ["can't", "denied", "error"].flatMap { $0.components(separatedBy: " ") }

            if(badErrorWords.filter { taskOutput.range(of: $0) != nil }.count != 0) {
                DDLogError(taskOutput)
            } else {
                DDLogInfo(taskOutput)
            }
        }
    }

    // Mounts an install disk from the temporary path
    func mountInstallDisk(installDisk: OSVersion) {
        let dmgVersionNumber = installDisk.version
        let volume = "/Volumes/\(installDisk.appLabel)"
        mountedVolumes.append(volume)
        mountedVersions.append(installDisk)

        let taskOutput = handleTask(command: "/usr/bin/hdiutil", arguments: ["attach", "\(temporaryPath)\(dmgVersionNumber).dmg", "-noverify"])
        DDLogInfo("Mounting \(temporaryPath)\(dmgVersionNumber).dmg")
        DDLogInfo(taskOutput!)

        if((taskOutput?.contains("hdiutil: mount failed"))!) {
            delegate?.handleDiskError(message: "Unable to find image /var/tmp/Installers/\(dmgVersionNumber).dmg. No fallback version specified")

            mountedVolumes.removeAll { $0 == volume }
            mountedVersions = mountedVersions.filter { $0.version != installDisk.version }
        }
    }

    // Boilerplate NSTask functions with returning output
    private func handleTask(command: String, arguments: [String]) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.standardError = pipe
        task.launchPath = command
        task.arguments = arguments
        task.launch()
        task.waitUntilExit()

        let handle = pipe.fileHandleForReading
        let data = handle.readDataToEndOfFile()
        let taskOutput = String (data: data, encoding: String.Encoding.utf8)

        return taskOutput
    }

    private func registerForNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    public func unmountDisk(installDisk: OSVersion) {
        let taskOutput = handleTask(command: "/sbin/umount", arguments: ["/Volumes/\(installDisk.appLabel)"])
        let volume = "/Volumes/\(installDisk.appLabel)"

        mountedVolumes.removeAll { $0 == volume }
        mountedVersions = mountedVersions.filter { $0.version != installDisk.version }
        print(taskOutput!)
    }



    @objc func didMount(_ notification: NSNotification) {
        delegate?.refreshDiskStatus()
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            let newVolume = devicePath.components(separatedBy: CharacterSet.decimalDigits).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            let appLabel = newVolume.replacingOccurrences(of: "/Volumes/", with: "")
            if (mountedVolumes.contains(newVolume)) {

                guard let currentMountedVersion = (mountedVersions.filter { $0.appLabel == appLabel }).first
                    else {
                        return
                }

                delegate?.diskMounted(diskImage: currentMountedVersion)
                currentMountedVersion.updateIcon()
                print("macOS Installer Volume mounted -- macOS Install possible at this time")
            } else {
                let appLabel = devicePath.replacingOccurrences(of: "/Volumes/", with: "")
                let appPath = "\(devicePath)/\(appLabel).app"
                if(URL(fileURLWithPath: appPath).filestatus != .isNot) {
                    let installVersion = VersionNumbers.getVersionForName(appLabel)
                    let installDisk = OSVersion(diskImagePath: devicePath, appLabel: appLabel, version: installVersion)

                    if(compatibilityChecker.canInstall(version: installDisk.version)) {
                        mountedVolumes.append(devicePath)
                        mountedVersions.append(installDisk)

                        delegate?.diskMounted(diskImage: installDisk)
                        installDisk.updateIcon()
                        print("macOS Installer Volume mounted -- macOS Install possible at this time")
                    }
                }
            }
        }
    }

    @objc func didUnmount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            let removedVolume = devicePath.components(separatedBy: CharacterSet.decimalDigits).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            let appLabel = removedVolume.replacingOccurrences(of: "/Volumes/", with: "")
            if (mountedVolumes.contains(removedVolume)) {
                mountedVolumes.removeAll { $0 == removedVolume }
                guard let unmountedVersion = (mountedVersions.filter { $0.appLabel == appLabel }).first
                    else {
                        print("Unable to determine unmounted version -- you can safely ignore this probably")
                        return
                }
                mountedVersions.removeAll { $0.version == unmountedVersion.version }
                delegate?.diskUnmounted(diskImage: unmountedVersion)
                print("macOS Installer Volume unmounted -- macOS Install impossible at this time")
            }
        }
    }
}
protocol MountDiskDelegate {
    func handleDiskError(message: String)
    func diskMounted(diskImage: OSVersion)
    func diskUnmounted(diskImage: OSVersion)
    func refreshDiskStatus()
}

