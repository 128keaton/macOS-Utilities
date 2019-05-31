//
//  DiskImage.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class DiskImage: FileSystemItem, Codable, Equatable {
    var contentHint: String?
    var itemPath: String? = nil
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

    var isMountable: Bool {
        if let mountable = self.potentiallyMountable {
            return mountable && self.mountPoint != nil
        }

        return false
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contentHint = try container.decodeIfPresent(String.self, forKey: .contentHint)
        self.devEntry = try container.decodeIfPresent(String.self, forKey: .devEntry)
        self.potentiallyMountable = try container.decodeIfPresent(Bool.self, forKey: .potentiallyMountable)
        self.unmappedContentHint = try container.decodeIfPresent(String.self, forKey: .unmappedContentHint)
        self.mountPoint = try container.decodeIfPresent(String.self, forKey: .mountPoint)

        if isMountable,
            let validMountPoint = self.mountPoint,
            validMountPoint.fileURL.filestatus != .isNot {
            ItemRepository.shared.scanForMountedInstallers()
            DDLogVerbose("Mounted at: \(validMountPoint)")
        }
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

    static func == (lhs: DiskImage, rhs: DiskImage) -> Bool {
        return lhs.id == rhs.id && lhs.itemPath == rhs.itemPath
    }
}
