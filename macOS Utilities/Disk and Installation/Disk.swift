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
            if(self.mountedDisk == nil) {
                print("Unmounted disk: \(self)")
            } else {
            }
        }
    }
    var isRemoteDisk: Bool = false
    var diskType: DiskType = .physical
    var path: String? = nil
    var mountPath: String? = nil

    var isMounted: Bool {
        return mountedDisk != nil
    }

    var isMountable: Bool {
        return path != nil || mountedDisk != nil
    }

    var description: String {
        return "Disk: \n\t Type: \(self.diskType) \n\t  Remote: \(self.isRemoteDisk) \n\t  Mounted: \(self.isMounted) \n\t  Mountable: \(self.isMountable) \n\t  \(self.mountedDisk == nil ? "No mounted disk" : " \n \(self.mountedDisk!.description)")\n"
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
        self.mountedDisk = MountedDisk(disk: self, matchedDiskOutput: matchedDiskOutput)
    }

    convenience init() {
        self.init(diskType: .physical)
    }

    public func scanForVolume(disk: Disk, volumeName: String) {
        if let validMountPath = self.mountPath {
            let mountURL = URL(fileURLWithPath: validMountPath)

            if(mountURL.filestatus == .isNot) {
                DDLogInfo("MountedDisk /Volumes/\(volumeName) does not appear to be a valid mount.")
            }

            DiskRepository.shared.getRawDiskInfo(path: validMountPath) { (potentialDiskInfo) in
                if let diskInfo = potentialDiskInfo {
                    self.mountedDisk = MountedDisk(disk: self, matchedDiskOutput: diskInfo)
                }
            }
        }
    }
    
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    public func updateMountedDisk(mountedDisk: MountedDisk){
        self.mountedDisk = mountedDisk
        DDLogInfo("Disk Updated: \n \(self)")
    }

    public func mount() {
        if (isMountable) {
            DiskRepository.shared.mount(disk: self) { (mountedDisk) in
                if let newMountedDisk = mountedDisk{
                    self.mountedDisk = newMountedDisk
                }
            }
        }
    }

    enum DiskType: String {
        case nfs = "NFS"
        case dmg = "DMG"
        case physical = "Physical"
    }

}

