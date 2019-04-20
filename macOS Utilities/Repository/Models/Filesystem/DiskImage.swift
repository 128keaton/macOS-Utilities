//
//  DiskImage.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct DiskImage: FileSystemItem, Codable, Equatable {
    var contentHint: String?
    var devEntry: String?
    var potentiallyMountable: Bool? = false
    var unmappedContentHint: String?
    var mountPoint: String?

    var id: String {
        return unmappedContentHint ?? String.random(12).md5Value
    }

    var itemType: FileSystemItemType {
        return .diskImage
    }

    var volumeName: String {
        return self.mountPoint == nil ? "Not mounted" : String(self.mountPoint!.split(separator: "/").last!)
    }

    var isMounted: Bool {
        return self.mountPoint != nil
    }

    var containsInstaller: Bool {
        if let mountPoint = self.mountPoint {
            return mountPoint.contains("Install macOS") || mountPoint.contains("Install OS X")
        }
        return false
    }


    func getMountPoint() -> String {
        return self.mountPoint ?? "Not mounted"
    }

    var description: String {
        return "Disk Image: \(self.mountPoint ?? "Not mounted")"
    }

    private enum CodingKeys: String, CodingKey {
        case contentHint = "content-hint"
        case devEntry = "dev-entry"
        case potentiallyMountable = "potentially-mountable"
        case unmappedContentHint = "unmapped-content-hint"
        case mountPoint = "mount-point"
    }
}
