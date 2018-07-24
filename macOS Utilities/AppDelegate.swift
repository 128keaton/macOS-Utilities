//
//  AppDelegate.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var utilitiesMenu: NSMenu?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let utilities = try! FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities")
        for file in utilities {
            if file != ".DS_Store" && file != ".localized"{
                let title = file.replacingOccurrences(of: ".app", with: "")
                let menuItem = NSMenuItem(title: title, action: #selector(openApp(sender:)), keyEquivalent: "")
                utilitiesMenu!.addItem(menuItem)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func openApp(sender: NSMenuItem) {
        let path = sender.title
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/\(path).app"))
    }

}

