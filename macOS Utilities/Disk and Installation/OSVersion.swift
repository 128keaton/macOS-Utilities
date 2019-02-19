//
//  OSVersion.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/18/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class OSVersion {
    var diskImagePath: String
    var appLabel: String
    var version: String
    var icon: NSImage?
    
    init(diskImagePath: String, appLabel: String, version: String){
        self.diskImagePath = diskImagePath
        self.appLabel = appLabel
        self.version = version
    }
    
    func updateIcon(){
        self.icon = findIconFor(applicationPath: "\(getVolumePath())/\(appLabel).app")
    }
    
    func getVolumePath() -> String{
        return "/Volumes/\(appLabel)/"
    }
}
