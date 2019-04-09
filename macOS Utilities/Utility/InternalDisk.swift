//
//  InternalDisk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class MountedDisk: CustomStringConvertible {
    var mountPoint: String = "/dev/null"
    var name: String = "Invalid Disk"
    var size: Double = 0.0
    var measurementUnit: String = "GB"
    
    var isValid: Bool {
        return self.mountPoint != "/dev/null" && self.name != "Not applicable (no file system)"
    }
    var isInstallable: Bool {
        return self.size > 150.0 || self.measurementUnit == "TB"
    }

    var description: String {
        return "InternalDisk: \n\t Name: \(self.name) \n\t Size: \(self.size) \(self.measurementUnit) \n\t Valid: \(self.isValid) \n\t Installable: \(self.isInstallable) \n\t Mount Point: \(self.mountPoint)\n"
    }

    init(matchedDiskOutput: String) {
        if let matchedSize = matchedDiskOutput.matches("([0-9]+( |.[0-9]+ )(GB|TB))", stripR: ["\\*", "\\+"]).first {
            if(matchedSize.contains("TB")){
                self.measurementUnit = "TB"
            }
            
            self.size = matchedSize.doubleValue
        }

        if let matchedMountPoint = matchedDiskOutput.matches("disk([0-9]*)s.").first {
            self.mountPoint = "/dev/\(matchedMountPoint)"
        }

        self.name = getNameFromDiskUtil()
    }

    private func getNameFromDiskUtil() -> String {
        var name = self.name
        
        if let diskUtilInfo = TaskHandler.createTask(command: "/usr/sbin/diskutil", arguments: ["info", self.mountPoint]){
            if let volumeName = diskUtilInfo.matches("Volume Name: *.*").first{
                name = volumeName.replacingOccurrences(of: "Volume Name: *", with: "", options: .regularExpression)
            }
        }
        
        return name
    }
}
