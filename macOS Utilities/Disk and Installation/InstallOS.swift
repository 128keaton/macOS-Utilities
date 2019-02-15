//
//  InstallOS.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class InstallOS{
    static func kickoffMacOSInstall(){
        let filePath = "/Applications/Install macOS.app"
        
        if FileManager.default.fileExists(atPath: filePath) {
            print("Starting macOS Install")
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Install macOS.app"))
        } else {
            print("Unable to start macOS Install. Missing kickstart application")
            let alert: NSAlert = NSAlert()
            alert.messageText = "Unable to start macOS Install"
            alert.informativeText = "macOS Utilities was unable find application \n \(filePath)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
