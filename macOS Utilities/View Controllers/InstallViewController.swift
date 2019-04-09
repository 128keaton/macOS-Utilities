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

    private var compatibilityChecker: Compatibility = Compatibility()
    private var versionNumbers: VersionNumbers = VersionNumbers()
    private var preferences = Preferences.shared
    private var installers = [Installer]()

    private let pageControllerDelegate = (NSApplication.shared.delegate as? AppDelegate)!
    private let infoMenu = (NSApplication.shared.delegate as! AppDelegate).infoMenu

    public var selectedVersion: Installer? = nil

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(InstallViewController.getInstallableVersions), name: ItemRepository.newInstaller, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        checkForMetal()
        verifyMemoryAmount()
        verifyHDDSize()
        getInstallableVersions()
    }

    @objc func getInstallableVersions() {
        let returnedInstallers = ItemRepository.shared.getInstallers()
        if(returnedInstallers != self.installers) {
            self.installers.indices.forEach { self.infoMenu?.removeItem(at: $0) }
            self.installers = returnedInstallers
            self.installers.forEach { self.infoMenu?.insertItem(withTitle: "\($0.versionNumber) - \($0.canInstall ? "🙂" : "☹️")", action: nil, keyEquivalent: "", at: 0) }
            self.infoMenu?.insertItem(NSMenuItem.separator(), at: (self.installers.count))
            if(Thread.isMainThread == true) {
                self.tableView.reloadData()
            } else {
                DispatchQueue.main.async {
                    if self.tableView != nil {
                        self.tableView.reloadData()
                    }
                }
            }
        }
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
        ApplicationUtility.shared.open("Disk Utility")
    }

    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        pageControllerDelegate.goToPreviousPage()
    }

    @IBAction func nextButtonClicked(_ sender: NSButton) {
        pageControllerDelegate.goToNextPage()
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
            cell.textField?.stringValue = installer.versionName
            cell.imageView?.image = installer.icon ?? nil
            return cell
        }

        return nil
    }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        tableView.deselectAll(self)
        if(installers[row].canInstall) {
            installButton.isEnabled = true

            installers.forEach { $0.isSelected = false }
            installers[row].isSelected = true

            return true
        }
        return false
    }

    override open func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        let point = self.view.convert(event.locationInWindow, from: nil)
        let rowIndex = tableView.row(at: point)

        if rowIndex < 0 { // We didn't click any row
            tableView.deselectAll(nil)
            installButton.isEnabled = false
            installers.forEach { $0.isSelected = false }
        }
    }
}

