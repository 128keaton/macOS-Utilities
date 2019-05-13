//
//  Share,swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

struct Share: FileSystemItem {
    var type: String?
    var mountPoint: String?
    
    var id: String {
        return String("\(mountPoint)-\(type ?? "None")").md5Value
    }
    
    var itemType: FileSystemItemType {
        return .remoteShare
    }
    
    var description: String {
        return "Share: Mount Point: \(self.mountPoint ?? "not mounted")"
    }
    
    init(type: String?, mountPoint: String?){
        self.type = type
        self.mountPoint = mountPoint
        
        if let validMountPoint = self.mountPoint{
            HardDriveImageUtility.mountDiskImagesAt(validMountPoint)
        }
    }
    
    static func == (lhs: Share, rhs: Share) -> Bool {
        return lhs.type == rhs.type && lhs.mountPoint == rhs.mountPoint
    }
}
