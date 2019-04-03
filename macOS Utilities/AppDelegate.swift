//
//  AppDelegate.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import PaperTrailLumberjack

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var utilitiesMenu: NSMenu?
    @IBOutlet weak var infoMenu: NSMenu?

    let modelYearDetermination = ModelYearDetermination()

    private let applicationManager = ApplicationRepository.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        buildInfoMenu()

        DiskRepository.shared.mountDiskImagesAt("/Users/keatonburleson/Documents/NFS")
        
        for utility in applicationManager.getUtilities(){
            let utilityMenuItem = NSMenuItem(title: utility.name, action: #selector(openApp(sender:)), keyEquivalent: "")
            utilitiesMenu!.addItem(utilityMenuItem)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        DiskRepository.shared.unmountAllDiskImages()
    }

    @objc func openApp(sender: NSMenuItem) {
        Application.open(sender.title, isUtility: true)
    }

    func buildInfoMenu() {
        if(infoMenu?.items.count ?? 0 > 0) {
            infoMenu?.addItem(NSMenuItem.separator())
        }

        infoMenu?.addItem(withTitle: Sysctl.model, action: nil, keyEquivalent: "")
        if let serial = serialNumber {
            infoMenu?.addItem(withTitle: serial, action: nil, keyEquivalent: "")
            infoMenu?.addItem(NSMenuItem.separator())
            infoMenu?.addItem(withTitle: "Check Warranty", action: #selector(AppDelegate.openSerialLink), keyEquivalent: "")
        }
    }

    // Unfortunately, this is rate limited :/
    @objc func openSerialLink() {
        if let serial = serialNumber {
            NSWorkspace().open(URL(string: "https://checkcoverage.apple.com/us/en/?sn=\(serial)")!)
        }
    }

    var serialNumber: String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

        guard platformExpert > 0 else {
            return nil
        }

        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
            return nil
        }

        IOObjectRelease(platformExpert)
        return serialNumber
    }
}
