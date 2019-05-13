//
//  HardDriveImageUtility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class HardDriveImageUtility {
    public static var allImagesUnmounted: Bool {
        return self.cachedDiskImages.count == 0
    }

    private static let diskModificationQueue = DispatchQueue(label: "NSDiskModificationQueue")

    private static var cachedDiskImages = [DiskImage]() {
        didSet {
            NotificationCenter.default.post(name: GlobalNotifications.newShares, object: nil)
        }
    }

    public static func ejectAllDiskImages(completion: @escaping (Bool) -> ()) {
        if(allImagesUnmounted) {
            completion(true)
        }

        cachedDiskImages.forEach {
            ejectDiskImage($0, completion: { (didEject) in
                if allImagesUnmounted {
                    completion(true)
                }
            })
        }
    }

    public static func ejectDiskImage(_ diskImage: DiskImage, completion: @escaping (Bool) -> ()) {
        DDLogVerbose("Ejecting disk image: \(diskImage)")
        if let deviceIdentifier = diskImage.devEntry {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eject", deviceIdentifier], returnEscaping: { (taskOutput) in
                if let diskUtilOutput = taskOutput {
                    if diskUtilOutput.contains("ejected") {
                        self.diskModificationQueue.sync {
                            DDLogVerbose("Ejected disk image: \(diskImage)")

                            self.cachedDiskImages.removeAll { $0 == diskImage }
                            self.cachedDiskImages.removeAll { $0.isMounted == false }
                            completion(true)
                        }
                    } else {
                        DDLogError("Unable to eject disk image: \(deviceIdentifier) \(diskUtilOutput)")
                        completion(false)
                    }
                }
            })
        }
    }

    public static func mountDiskImage(_ at: String) {
        if(!at.contains(".dmg")) {
            DDLogError("Disk \(at) is not a disk image or is not mountable")
        }

        TaskHandler.createTask(command: "/usr/bin/hdiutil", arguments: ["mount", "-plist", "\(at)", "-noverify"], silent: true) { (taskOutput) in
            DDLogInfo("Mounting \(at)")

            if((taskOutput?.contains("hdiutil: mount failed"))!) {
                DDLogError("Disk \(at) could not be mounted: \(taskOutput ?? "No output from hdiutil")")
            } else {
                if let mountOutput = taskOutput {
                    do {
                        let mountOutput: hdiutilMount = try OutputParser().parseOutput(mountOutput, toolType: .hdiutil, outputType: .mount)
                        if let mountableDiskImage = mountOutput.mountableDiskImage {
                            self.diskModificationQueue.sync {
                                self.cachedDiskImages.append(mountableDiskImage)
                            }
                        }
                    } catch {
                        DDLogError("Could not mount disk image at: \(at). \n\(error)")
                    }
                }
            }
        }
    }

    public static func mountDiskImagesAt(_ folderPath: String) {
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
}
