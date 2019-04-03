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

class Disk: CustomStringConvertible {
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
        let random = self.randomString(length: 12)

        guard let data = random.data(using: String.Encoding.utf8) else { return random }

        let hash = data.withUnsafeBytes { (bytes: UnsafePointer<Data>) -> [UInt8] in
            var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            CC_SHA1(bytes, CC_LONG(data.count), &hash)
            return hash
        }

        return hash.map { String(format: "%02x", $0) }.joined()
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
        
        let newMountedDisk = MountedDisk(existingDisk: self, matchedDiskOutput: matchedDiskOutput)
        DDLogInfo("Attaching \(newMountedDisk) to \(self)")
    }
    
    convenience init() {
        self.init(diskType: .physical)
    }
    
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    public func updateMountedDisk(mountedDisk: MountedDisk) {
        self.mountedDisk = mountedDisk
    }
    
    enum DiskType: String {
        case nfs = "NFS"
        case dmg = "DMG"
        case physical = "Physical"
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
