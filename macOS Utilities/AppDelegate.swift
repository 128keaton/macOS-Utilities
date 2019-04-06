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

    private let itemRepository = ItemRepository.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        buildInfoMenu()
        ItemRepository.shared.getApplications().filter { $0.isUtility == true }.map { NSMenuItem(title: $0.name, action: #selector(openApp(sender:)), keyEquivalent: "") }.forEach { utilitiesMenu?.addItem($0) }

        let installersShareIP = Preferences.shared.getServerIP()
        let installersSharePath = Preferences.shared.getServerPath()
        let installersLocalPath = Preferences.shared.getMountPoint()

        DiskUtility.shared.mountNFSShare(shareURL: "\(installersShareIP):\(installersSharePath)", localPath: installersLocalPath) { (didSucceed) in
            if(didSucceed) {
                DiskUtility.shared.mountDiskImagesAt(installersLocalPath)
            }
        }
    }

    @objc func openApp(sender: NSMenuItem) {
        ApplicationUtility.shared.open(sender.title)
    }

    private func checkIfReadyToTerminate(){
        if applicationShouldTerminate(NSApplication.shared) == .terminateNow{
            NSApplication.shared.terminate(self)
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if(DiskUtility.shared.allSharesAndInstallersUnmounted == false){
            DiskUtility.shared.ejectAll { (didComplete) in
                DDLogInfo("Finished ejecting? \(didComplete)")
                self.checkIfReadyToTerminate()
            }
            return .terminateLater
        }
        
        return .terminateNow
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

    @IBAction func reloadPreferences(_ sender: NSMenuItem) {
        ItemRepository.shared.reloadAllItems()
    }

    @IBAction func ejectAll(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
        }
    }

    @IBAction func reloadInstallers(_ sender: NSMenuItem) {
        ItemRepository.shared.getInstallers().forEach { $0.refresh() }
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
