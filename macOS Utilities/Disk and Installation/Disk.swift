//
//  InstallDisk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack
import CommonCrypto

class Disk: CustomStringConvertible, Equatable {
    var mountedDisk: MountedDisk? = nil {
        didSet {
            if self.mountedDisk != nil && self.mountedDisk?.isValid == true {
                self.mountAction?.action()
            }
        }
    }

    var isRemoteDisk: Bool = false
    var diskType: DiskType = .physical
    var path: String? = nil
    var mountPath: String? = nil
    var devEntry: String? = nil

    var mountAction: DiskAction? = nil

    var isMounted: Bool {
        return mountedDisk != nil
    }

    var isMountable: Bool {
        return path != nil || mountedDisk != nil
    }

    var description: String {
        return "Disk: \n\t Type: \(self.diskType) \n\t Entry: \(self.devEntry ?? "No entry")  \n\t   Remote: \(self.isRemoteDisk) \n\t  Mounted: \(self.isMounted) \n\t  Mountable: \(self.isMountable) \n\t  \(self.mountedDisk == nil ? "No mounted disk" : " \n \(self.mountedDisk!.description)")\n"
    }

    var uniqueDiskID: String {
        return String.random(12).md5Value
    }

    init(diskType: DiskType, isRemoteDisk: Bool, path: String?, mountPath: String?) {
        if let diskPath = path {
            self.path = diskPath
        }
        if let mountVolumePath = mountPath {
            self.mountPath = mountVolumePath
        }

        self.diskType = diskType
        self.isRemoteDisk = isRemoteDisk
    }


    convenience init(diskType: DiskType) {
        self.init(diskType: diskType, isRemoteDisk: false, path: nil, mountPath: nil)
    }

    convenience init(diskType: DiskType, matchedDiskOutput: String) {
        self.init(diskType: diskType)
        self.mountedDisk = MountedDisk(existingDisk: self, matchedDiskOutput: matchedDiskOutput)
    }

    convenience init() {
        self.init(diskType: .physical)
    }

    public func updateMountedDisk(mountedDisk: MountedDisk) {
        self.mountedDisk = mountedDisk
    }

    public func eject() {
        if let devEntry = self.devEntry {
            TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["eject", devEntry]) { (ejectOutput) in
                print(ejectOutput ?? "No output")
                self.mountedDisk = nil
            }
        }
    }

    enum DiskType: String {
        case nfs = "NFS"
        case dmg = "DMG"
        case physical = "Physical"
    }

    static func == (lhs: Disk, rhs: Disk) -> Bool {
        return lhs.uniqueDiskID == rhs.uniqueDiskID
    }
}

final class DiskAction: NSObject {
    private let _action: () -> ()

    init(action: @escaping () -> ()) {
        _action = action
        super.init()
    }

    func action() {
        _action()
    }
}
