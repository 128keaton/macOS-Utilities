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

class InstallerViewController: NSViewController {
    @IBOutlet weak var metalStatus: NSButton!
    @IBOutlet weak var hddStatus: NSButton!
    @IBOutlet weak var memoryStatus: NSButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var installButton: NSButton!

    private var versionNumbers: VersionNumbers = VersionNumbers()
    private var installers = [Installer]()

    private let preferenceLoader: PreferenceLoader? = (NSApplication.shared.delegate as! AppDelegate).preferenceLoader

    public var selectedVersion: Installer? = nil

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(InstallerViewController.getInstallableVersions), name: ItemRepository.newInstaller, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        //  checkForMetal()
        //  verifyMemoryAmount()
        // verifyHDDSize()
        getInstallableVersions()
    }

    @objc func getInstallableVersions() {
        let returnedInstallers = ItemRepository.shared.getInstallers()
        if(returnedInstallers != installers) {
            installers = returnedInstallers.sorted(by: { $0.comparibleVersionNumber > $1.comparibleVersionNumber && $0.isFakeInstaller == false })
            if(Thread.isMainThread == true) {
                self.tableView.reloadData()
            } else {
                DispatchQueue.main.async {
                    if self.tableView != nil {
                        self.tableView.reloadData()
                        self.selectFirstInstallable()
                    }
                }
            }
        }
    }

    private func deselectAllInstallers(shouldDisableInstallButton: Bool = true) {
        if(shouldDisableInstallButton && installButton.isEnabled) {
            installButton.isEnabled = false
            removeTouchBarNextButton()
        } else if (!shouldDisableInstallButton && !installButton.isEnabled) {
            installButton.isEnabled = true
            addTouchBarNextButton()
        }

        ItemRepository.shared.unsetAllSelectedInstallers()
        installers.forEach { $0.isSelected = false }
    }

    private func selectFirstInstallable() {
        if let firstInstallable = (self.installers.first { $0.canInstall }) {
            if let firstInstallableIndex = self.installers.firstIndex(of: firstInstallable) {
                self.tableView.selectRowIndexes(IndexSet(integer: firstInstallableIndex), byExtendingSelection: false)
                ItemRepository.shared.setSelectedInstaller(firstInstallable)
                self.installButton.isEnabled = true
                addTouchBarNextButton()
            }
        }
    }

    /*  func checkForMetal() {
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
    }*/

    @IBAction func showPopover(sender: NSButton) {
        let popoverController = storyboard?.instantiateController(withIdentifier: "InfoPopoverViewController") as! InfoPopoverViewController

        /* if(sender == memoryStatus) {
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
                    popoverController.buttonAction = #selector(InstallerViewController.openDiskUtility)
                    popoverController.buttonText = "Open Disk Utility"
                #endif
            } else if(!compatibilityChecker.hasFormattedHDD && !compatibilityChecker.hasLargeEnoughHDD) {
                popoverController.message = "Your machine does not have an installable storage device, or the storage device is improperly formatted"
                popoverController.buttonAction = #selector(InstallerViewController.openDiskUtility)
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

        let entryRect = sender.convert(sender.bounds, to: NSApp.keyWindow?.contentView)
        popover.show(relativeTo: entryRect, of: (NSApp.keyWindow?.contentView)!, preferredEdge: .minY)*/
    }

    @objc func openDiskUtility() {
        ApplicationUtility.shared.open("Disk Utility")
    }

    @IBAction @objc func cancelButtonClicked(_ sender: Any?) {
        PageController.shared.goToPreviousPage()
    }

    @IBAction @objc func nextButtonClicked(_ sender: Any?) {
        PageController.shared.goToNextPage()
    }

    func removeTouchBarNextButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.backPageController]
        }
    }

    func addTouchBarNextButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.backPageController, .nextPageController]
        }
    }
}

extension InstallerViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return installers.count
    }
}

extension InstallerViewController: NSTableViewDelegate, NSTableViewDelegateDeselectListener {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let installer = installers[row]

        if let installerCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "osCell"), owner: nil) as? InstallerCellView {
            installerCell.installer = installer
            return installerCell
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        tableView.deselectAll(self)

        let potentialInstaller = installers[row]

        if(potentialInstaller.canInstall) {
            deselectAllInstallers(shouldDisableInstallButton: false)
            ItemRepository.shared.setSelectedInstaller(potentialInstaller)
            potentialInstaller.isSelected = true
        } else {
            installButton.isEnabled = false
            removeTouchBarNextButton()
            DDLogInfo("Unable to install \(potentialInstaller) on machine \(Sysctl.model) ")
        }

        return potentialInstaller.canInstall
    }

    func tableView(_ tableView: NSTableView, didDeselectAllRows: Bool) {
        if(didDeselectAllRows) {
            DDLogInfo("Deselecting all installers/rows in \(self)")
            deselectAllInstallers()
        }
    }
}

@available(OSX 10.12.1, *)
extension InstallerViewController: NSTouchBarDelegate {

    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.backPageController]

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        case NSTouchBarItem.Identifier.backPageController:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGoBackTemplate")!, target: self, action: #selector(cancelButtonClicked(_:)))
            return item

        case NSTouchBarItem.Identifier.nextPageController:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGoForwardTemplate")!, target: self, action: #selector(nextButtonClicked(_:)))
            return item

        default: return nil
        }
    }
}
