//
//  FilesystemItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

enum FileSystemItemType {
    case disk
    case partition
    case diskImage
    case remoteShare
    case logicalVolumeGroup
}

protocol FileSystemItem: CustomStringConvertible {
    var itemType: FileSystemItemType { get }
    var id: String { get }
}
