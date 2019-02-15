//
//  MountDisk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class MountDisk {
    let temporaryPath = "/var/tmp/Installers/"
    var delegate: MountDiskDelegate? = nil

    private var macOSVolume: String? = nil
    private let versionNumbers: VersionNumbers = VersionNumbers()
    private var host: String
    private var hostPath: String
    private var currentVersion: String? = nil

    init(host: String, hostPath: String) {
        self.host = host
        self.hostPath = hostPath
        registerForNotifications()
        mountInstallerServer()
    }

    func getInstallerDiskImages() -> [String: String] {
        var diskImages = [String: String]()

        let fileManager = FileManager.default
        let installersURL = URL(fileURLWithPath: temporaryPath)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: installersURL, includingPropertiesForKeys: nil)
            for file in fileURLs {
                let fileName = file.lastPathComponent
                if(fileName.contains(".dmg")) {
                    let rawVersion = fileName.replacingOccurrences(of: ".dmg", with: "")
                    diskImages[rawVersion] = versionNumbers.getNameForVersion(rawVersion)
                }
            }
        } catch {
            print("Error listing the installers: \(error.localizedDescription)")
        }

        return diskImages
    }

    private func createInstallersPath() {
        let temporaryPathURL = URL(fileURLWithPath: temporaryPath)
        // Checks to see if the temporary dir is created
        if(temporaryPathURL.filestatus == .isNot) {
            let taskOutput = handleTask(command: "/bin/mkdir", arguments: [temporaryPath])
            print("Creating directory: /n \(taskOutput!)")
            return
        }

        print("Temporary path \(temporaryPath) already exists.")
    }

    private func mountInstallerServer() {
        createInstallersPath()
        let taskOutput = handleTask(command: "/sbin/mount", arguments: ["-t", "nfs", "-o", "soft,intr,rsize=8192,wsize=8192,timeo=900,retrans=3,proto=tcp", "\(self.host):\(self.hostPath)", temporaryPath])
        print("Mounting installer server path output: \(taskOutput!)")
    }

    // Mounts an install disk from the temporary path
    func mountInstallDisk(_ version: String, _ fallbackVersion: String?) {
        let dmgVersionNumber = versionNumbers.getVersionForName(version)
        macOSVolume = "/Volumes/\(version)"
        currentVersion = dmgVersionNumber

        let taskOutput = handleTask(command: "/usr/bin/hdiutil", arguments: ["attach",  "\(temporaryPath)\(dmgVersionNumber).dmg", "-noverify"])
        print("Mounting \(temporaryPath)\(dmgVersionNumber).dmg")
        print(taskOutput!)
        if((taskOutput?.contains("hdiutil: mount failed"))! && fallbackVersion != nil) {
           let _ = mountInstallDisk(fallbackVersion!, nil)
            delegate?.handleDiskError(message: "Unable to find image /var/tmp/Installers/\(version).dmg. Falling back on previous version")
        } else if((taskOutput?.contains("hdiutil: mount failed"))! && fallbackVersion == nil) {
            delegate?.handleDiskError(message: "Unable to find image /var/tmp/Installers/\(version).dmg. No fallback version specified")
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

    public func unmountActiveDisk(){
        if let currentVolume = macOSVolume{
            let taskOutput = handleTask(command: "/sbin/umount", arguments: [currentVolume])
            print(taskOutput!)
        }
    }
    
    @objc func didMount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String, let volume = macOSVolume {
            if (devicePath.contains(volume) && currentVersion != nil) {
                delegate?.readyToInstall(volumePath: volume, macOSVersion: currentVersion!)
                print("macOS Installer Volume mounted -- macOS Install possible at this time")
            }
        }
    }

    @objc func didUnmount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String, let volume = macOSVolume {
            if (devicePath.contains(volume)) {
                delegate?.unreadyToInstall()
                print("macOS Installer Volume unmounted -- macOS Install impossible at this time")
            }
        }
    }
}
protocol MountDiskDelegate {
    func handleDiskError(message: String)
    func readyToInstall(volumePath: String, macOSVersion: String)
    func unreadyToInstall()
}

extension URL {
    enum Filestatus {
        case isFile
        case isDir
        case isNot
    }

    var filestatus: Filestatus {
        get {
            let filestatus: Filestatus
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    // file exists and is a directory
                    filestatus = .isDir
                }
                else {
                    // file exists and is not a directory
                    filestatus = .isFile
                }
            }
            else {
                // file does not exist
                filestatus = .isNot
            }
            return filestatus
        }
    }
}

