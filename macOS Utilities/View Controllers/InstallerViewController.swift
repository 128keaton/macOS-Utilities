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
    private var cachedPopover: NSPopover? = nil

    private let preferenceLoader: PreferenceLoader? = (NSApplication.shared.delegate as! AppDelegate).preferenceLoader

    public var selectedVersion: Installer? = nil

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(InstallerViewController.getInstallableVersions(notification:)), name: ItemRepository.newInstaller, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(InstallerViewController.getInstallableVersions(notification:)), name: ItemRepository.removeInstaller, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatusImages(_:)), name: DiskUtility.bootDiskAvailable, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateStatusImages()

        if (ItemRepository.shared.has(Installer.self) && installers.count == 0) {
            getInstallableVersions()
        }
    }

    @objc func updateStatusImages(_ aNotification: Notification? = nil) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateStatusImages()
            }
            return
        }

        metalStatus.image = MachineInformation.shared.GPUStatus
        memoryStatus.image = MachineInformation.shared.RAMStatus
        hddStatus.image = MachineInformation.shared.HDDStatus
    }

    @objc func getInstallableVersions(notification: Notification? = nil) {
        if let notification = notification,
            let installer = notification.object as? Installer,
            let userInfo = notification.userInfo as? [String: String] {

            if userInfo["type"] == "remove" {
                installers.removeAll { $0 == installer }
            } else if !installers.contains(installer) {
                installers.append(installer)
            }
        } else {
            installers = ItemRepository.shared.getInstallers()
        }

        installers.sort(by: { $0.comparibleVersionNumber > $1.comparibleVersionNumber && $0.isFakeInstaller == false })
        reloadInstallersTableView()
    }

    private func reloadInstallersTableView() {
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

    @IBAction func showPopover(sender: NSButton) {
        if let popoverContentViewController = storyboard?.instantiateController(withIdentifier: "InfoPopoverViewController") as? InfoPopoverViewController {
            var addDiskUtilityButton = (sender == hddStatus && !MachineInformation.shared.bootHDDIsValid)
            #if DEBUG
                addDiskUtilityButton = (sender == hddStatus)
            #endif

            if(sender == memoryStatus) {
                popoverContentViewController.message = MachineInformation.shared.RAMInformation
            }

            if(sender == metalStatus) {
                popoverContentViewController.message = MachineInformation.shared.GPUInformation
            }

            if(sender == hddStatus) {
                popoverContentViewController.message = MachineInformation.shared.HDDInformation
            }


            if self.cachedPopover == nil {
                let aPopover = NSPopover()
                aPopover.behavior = .transient
                aPopover.contentViewController = popoverContentViewController
                aPopover.animates = true
                self.cachedPopover = aPopover
            }

            if let popover = self.cachedPopover {
                if popover.contentViewController == nil || popover.contentViewController != popoverContentViewController {
                    popover.contentViewController = popoverContentViewController
                }

                if (addDiskUtilityButton) {
                    popoverContentViewController.buttonText = "Open Disk Utility"
                    popoverContentViewController.buttonAction = #selector(openDiskUtility)
                    popover.contentSize = NSSize(width: 350, height: 150)
                } else {
                    popover.contentSize = NSSize(width: 350, height: 115)
                }

                let entryRect = sender.convert(sender.bounds, to: NSApp.keyWindow?.contentView)
                popover.show(relativeTo: entryRect, of: (NSApp.keyWindow?.contentView)!, preferredEdge: .minY)
            }
        }
    }

    @objc func openDiskUtility() {
        //  ApplicationUtility.shared.open("Disk Utility")
    }

    @IBAction @objc func cancelButtonClicked(_ sender: Any?) {
        PageController.shared.goToPreviousPage()
    }

    @IBAction @objc func nextButtonClicked(_ sender: Any?) {
        PageController.shared.goToNextPage()
    }

    func removeTouchBarNextButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.closeCurrentWindow]
        }
    }

    func addTouchBarNextButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.closeCurrentWindow, .nextPageController]
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
        touchBar.defaultItemIdentifiers = [.closeCurrentWindow]

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        case NSTouchBarItem.Identifier.closeCurrentWindow:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSStopProgressTemplate")!, target: self, action: #selector(cancelButtonClicked(_:)))
            return item

        case NSTouchBarItem.Identifier.nextPageController:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGoForwardTemplate")!, target: self, action: #selector(nextButtonClicked(_:)))
            return item

        default: return nil
        }
    }
}
