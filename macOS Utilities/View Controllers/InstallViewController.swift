//
//  InstallViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/18/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class InstallViewController: NSViewController {
    @IBOutlet weak var metalStatus: NSButton!
    @IBOutlet weak var hddStatus: NSButton!
    @IBOutlet weak var memoryStatus: NSButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var installButton: NSButton!

    private var installableVersions: [OSVersion]? = []
    private var compatibilityChecker: Compatibility = Compatibility()
    private var versionNumbers: VersionNumbers = VersionNumbers()
    private var preferences = Preferences.shared
    /*   private var diskAgent: MountDisk? = nil {
        didSet {
            diskAgent?.delegate = self
        }
    }*/

    private var installers = [Installer]()
    private let infoMenu = (NSApplication.shared.delegate as! AppDelegate).infoMenu

       public var selectedVersion: Installer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkForMetal()
        verifyMemoryAmount()
        verifyHDDSize()

        let serverIP = preferences.getServerIP()
        let serverPath = preferences.getServerPath()

        DiskRepository.shared.delegate = self
        
        //  diskAgent = MountDisk(host: serverIP, hostPath: serverPath)
    }
    
    func getInstallableVersions() {
        let allInstallers = DiskRepository.shared.getInstallers()
        installers = allInstallers
    }

    /*
    func getInstallableVersions() {
      //  let diskAgent = self.diskAgent!
        let diskImages = diskAgent.getInstallerDiskImages().sorted(by: { $0.version > $1.version })

        for diskImage in diskImages {
            if(compatibilityChecker.canInstall(version: diskImage.version)) {
                infoMenu?.addItem(withTitle: diskImage.version, action: nil, keyEquivalent: "")
                taskQueue.async {
                    self.diskAgent!.mountInstallDisk(installDisk: diskImage)
                }
            }
        }

        if(diskImages.count == 0) {
            showErrorAlert(title: "macOS Install Error", message: "There were no installable versions found on the server (\(preferences.getServerIP())) compatible with this machine (\(Sysctl.model)).")
            DDLogError("No installable versions found on the server")
            DDLogInfo("Machine: \(Sysctl.model)")
            DDLogInfo("Server IP: \(preferences.getServerIP())")
            DDLogInfo("Installers found: \(diskImages.count)")
            infoMenu?.addItem(withTitle: "No installable versions found", action: nil, keyEquivalent: "")
        }
    }*/

    @IBAction func startOSInstall(sender: NSButton) {
        InstallOS.kickoffMacOSInstall()
    }

    func checkForMetal() {
        if compatibilityChecker.hasMetalGPU {
            metalStatus.image = NSImage(named: "SuccessIcon")
        } else {
            metalStatus.image = NSImage(named: "AlertIcon")
        }
    }

    func verifyMemoryAmount() {
        if compatibilityChecker.hasEnoughMemory {
            memoryStatus.image = NSImage(named: "SuccessIcon")
        } else {
            memoryStatus.image = NSImage(named: "AlertIcon")
        }
    }

    func verifyHDDSize() {
        if compatibilityChecker.hasLargeEnoughHDD {
            hddStatus.image = NSImage(named: "SuccessIcon")
        } else {
            hddStatus.image = NSImage(named: "AlertIcon")
        }
    }

    @IBAction func showPopover(sender: NSButton) {
        let popoverController = storyboard?.instantiateController(withIdentifier: "InfoPopoverViewController") as! InfoPopoverViewController

        if(sender == memoryStatus) {
            if(compatibilityChecker.hasEnoughMemory) {
                popoverController.message = "This machine has more than 8GB of RAM."
            } else {
                popoverController.message = "This machine has less than 8GB of RAM. You can install, but the machine's performance might be dismal."
            }
        } else if(sender == metalStatus) {
            if(compatibilityChecker.hasMetalGPU) {
                popoverController.message = "This machine has only Metal compatible GPUs installed."
            } else {
                popoverController.message = "This machine has no Metal compatible GPUs or has a non-Metal compatible GPU installed."
            }
        } else {
            if(compatibilityChecker.hasFormattedHDD && compatibilityChecker.hasLargeEnoughHDD) {
                popoverController.message = "This machine has a primary storage device with a capacity of \(compatibilityChecker.storageDeviceSize) GB."
                #if DEBUG
                    popoverController.buttonAction = #selector(InstallViewController.openDiskUtility)
                    popoverController.buttonText = "Open Disk Utility"
                #endif
            } else if(!compatibilityChecker.hasFormattedHDD && !compatibilityChecker.hasLargeEnoughHDD) {
                popoverController.message = "Your machine does not have an installable storage device, or the storage device is improperly formatted"
                popoverController.buttonAction = #selector(InstallViewController.openDiskUtility)
                popoverController.buttonText = "Open Disk Utility"
            } else if(compatibilityChecker.hasFormattedHDD && !compatibilityChecker.hasLargeEnoughHDD) {
                popoverController.message = "This machine's HDD space is too low (\(compatibilityChecker.storageDeviceSize) GB)."
            }
        }

        let popover = NSPopover()
        if(popoverController.buttonText != nil && popoverController.buttonAction != nil) {
            popover.contentSize = NSSize(width: 250, height: 150)
        } else {
            popover.contentSize = NSSize(width: 250, height: 111)
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = popoverController

        let entryRect = sender.convert(sender.bounds, to: NSApp.mainWindow?.contentView)
        popover.show(relativeTo: entryRect, of: (NSApp.mainWindow?.contentView)!, preferredEdge: .minY)
    }

    @objc func openDiskUtility() {
        App.manager.openAppByName("Disk Utility", isUtility: true)
    }

}

extension InstallViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return installers.count
    }
}

extension InstallViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let installer = installers[row]

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "osCell"), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = installer.appLabel
            cell.imageView?.image = installer.icon ?? nil
            return cell
        }

        return nil
    }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        tableView.deselectAll(self)

        

        return true
    }

    override open func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        let point = self.view.convert(event.locationInWindow, from: nil)
        let rowIndex = tableView.row(at: point)

        if rowIndex < 0 { // We didn't click any row
            tableView.deselectAll(nil)
            installButton.isEnabled = false
        }
    }
}

extension InstallViewController: DiskRepositoryDelegate {
    func installersUpdated() {
        DispatchQueue.main.async {
            self.getInstallableVersions()
            self.tableView.reloadData()
        }
    }
}

/*extension InstallViewController: MountDiskDelegate {
    func handleDiskError(message: String) {
        self.showErrorAlert(title: "Disk Error", message: message)
        DDLogError(message)
    }

    func diskUnmounted(diskImage: OSVersion) {
        self.installableVersions?.removeAll { $0.version == diskImage.version }
        infoMenu?.items.removeAll { $0.title == diskImage.version }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func diskMounted(diskImage: OSVersion) {
        diskImage.updateIcon()
        if(diskImage.icon != nil) {
            self.installableVersions?.append(diskImage)
        }

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        DDLogInfo("Mounted disk: \(diskImage)")
    }

    func refreshDiskStatus() {
        DDLogVerbose("Refreshing disk status (maybe reformatted?)")
        verifyHDDSize()
    }
}
*/
