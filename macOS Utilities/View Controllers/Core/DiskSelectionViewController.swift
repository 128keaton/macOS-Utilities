//
//  DiskSelectionPopupViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack
import SwiftDisks

class DiskSelectionViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var nextButton: NSButton?
    @IBOutlet weak var diskProgressIndicator: NSProgressIndicator?
    @IBOutlet weak var installingVersionLabel: NSTextField?
    @IBOutlet weak var backButton: NSButton!

    private var selectedInstaller: Installer? = nil
    private var selectedDisk: DiskNode? = nil
    private var selectedDiskContainer: ChildDiskNode? = nil

    private var alreadyAppeared = false
    private var disks: [DiskNode] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView?.reloadData()
            }
        }
    }

    // MARK: Superclass overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        self.diskProgressIndicator?.stopSpinning()
        updateBackButton()
        getSelectedInstaller()

        #if DEBUG
        self.nextButton?.isEnabled = true
        #endif
        NotificationCenter.default.addObserver(self, selector: #selector(handleCancelButtonFromLoadingPage(_:)), name: WizardViewController.cancelButtonNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(newDisksHandler), name: GlobalNotifications.newDisks, object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateBackButton()
        getSelectedInstaller()

        if !alreadyAppeared {
            SwiftDisks.getAllDisks { (disks) in
                self.disks = disks.filter { (diskNode) -> Bool in
                    return diskNode.isBootDrive() && diskNode.isAPFS()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkAndAskAboutFusionDrive()
            }
        }

        PeerCommunicationService.instance.updateStatus("Choosing Disk")
        alreadyAppeared = true
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        self.reloadTableView()
        updateBackButton()
    }

    // MARK: Button actions
    @IBAction @objc func openDiskUtility(_ sender: NSButton) {
        NotificationCenter.default.post(name: GlobalNotifications.openApplication, object: "Disk Utility")
    }

    @IBAction @objc func backButtonClicked(_ sender: NSButton) {
        if PageController.shared.isInitialPage(self) {
            PageController.shared.dismissPageController()
        } else {
            PageController.shared.goToPreviousPage()
        }
    }

    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        SwiftDisks.getAllDisks(bypassCache: true) { (disks) in
            self.disks = disks.filter { (diskNode) -> Bool in
                return diskNode.isBootDrive() && diskNode.isAPFS()
            }
        }
        self.checkAndAskAboutFusionDrive()
    }

    @objc func newDisksHandler() {
        reloadTableView()
    }

    @objc func handleCancelButtonFromLoadingPage(_ notification: Notification) {
        if let cancelID = notification.object as? String,
            cancelID == "cancelErase" {

            var itemName = ""

            if let validDisk = self.selectedDisk {
                itemName = "disk \(validDisk.deviceID)"
            }

            if let currentTask = TaskHandler.lastTask,
                currentTask.isRunning {
                currentTask.terminate()
            }

            if showConfirmationAlert(question: "Do you want to continue?", text: "You have cancelled the erase on \"\(itemName)\". Do you want to continue with install?") {
                DispatchQueue.main.async {
                    self.showFinishPage(volumeName: itemName, preformatted: true)
                }
            } else {
                PageController.shared.dismissPageController()
            }
        }
    }

    // MARK: Functions
    private func checkAndAskAboutFusionDrive() {
        if !DiskUtility.hasFusionDrive {
            return
        }

        self.showConfirmationAlert(question: "Repair Fusion Drive?", text: "A potential Fusion Drive has been detected, do you want to try and repair it?", window: self.view.window!) { (modalResponse) in
            if modalResponse == .alertFirstButtonReturn {
                PageController.shared.goToLoadingPage(loadingText: "Repairing..", cancelButtonIdentifier: "repairFusionDrive")
                PeerCommunicationService.instance.updateStatus("Repairing Fusion Drive")
                DiskUtility.createFusionDrive { (message, didCreate) in
                    if didCreate {
                        DDLogVerbose(message)
                        DispatchQueue.main.async {
                            self.showFinishPage(volumeName: "Macintosh HD")
                        }
                    } else {
                        PageController.shared.goToPreviousPage()
                        DDLogError(message)
                    }
                }
            }
        }
    }

    private func reloadTableView() {
        if let _tableView = self.tableView {
            DispatchQueue.main.async {
                _tableView.reloadData()
            }
        }
        if let _progressView = self.diskProgressIndicator {
            DispatchQueue.main.async {
                _progressView.stopSpinning()
            }
        }
    }

    private func updateBackButton() {
        if PageController.shared.isInitialPage(self) {
            backButton.title = "Cancel"
        } else {
            backButton.title = "Back"
        }
    }

    private func getSelectedInstaller() {
        if let selectedInstaller = ItemRepository.shared.selectedInstaller {
            installingVersionLabel?.stringValue = "To install \(selectedInstaller.version.name)"
            installingVersionLabel?.isHidden = false
            self.selectedInstaller = selectedInstaller
        } else {
            installingVersionLabel?.isHidden = true
        }
    }

    private func removeTouchBarNextButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.backPageController]
        }
    }

    private func addTouchBarNextButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.backPageController, .nextPageController]
        }
    }
}

extension DiskSelectionViewController: NSTableViewDelegate, NSTableViewDelegateDeselectListener {
    fileprivate enum CellIdentifiers {
        static let DiskNameCell = "DiskNameID"
        static let DiskSizeCell = "DiskSizeID"
        static let PartitionNameCell = "PartitionNameID"
        static let PartitionSizeCell = "PartitionSizeID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        let storageDevice = self.disks[row]
        let invalidVolumeNames = ["VM", "Preboot", "Recovery"]

        if storageDevice.isBootDrive() && storageDevice.isAPFS() {
            if storageDevice.physicalDisk != nil {
                if let mountedDevice = storageDevice.children.first(where: { (childDisk) -> Bool in
                    return childDisk.type == .apfsVolume && !childDisk.volumeName.contains(" - Data") && !invalidVolumeNames.contains(childDisk.volumeName)
                }) {
                    if tableColumn == tableView.tableColumns[0] {
                        if (mountedDevice.volumeName != "None") {
                            text = "\(mountedDevice.volumeName) - (\(storageDevice.deviceID))"
                        } else {
                            text = mountedDevice.deviceID
                        }
                        cellIdentifier = CellIdentifiers.PartitionNameCell
                    } else if tableColumn == tableView.tableColumns[1] {
                        text = "\(mountedDevice.size / 1024 / 1024 / 1024) GB"
                        cellIdentifier = CellIdentifiers.DiskSizeCell
                    }
                }
            }
        }


        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        self.tableView?.deselectAll(self)

        let storageDevice = self.disks[row]

        DDLogVerbose("Disk/Partition Selected: \(storageDevice)")
        print("Disk/Partition Selected: \(storageDevice)")
        let invalidVolumeNames = ["VM", "Preboot", "Recovery"]

        if let physicalDisk = storageDevice.physicalDisk,
            let mountedDevice = storageDevice.children.first(where: { (childDisk) -> Bool in
                return childDisk.type == .apfsVolume && !childDisk.volumeName.contains(" - Data") && !invalidVolumeNames.contains(childDisk.volumeName)
            })
        {
            self.selectedDiskContainer = mountedDevice
            self.selectedDisk = physicalDisk
            nextButton?.isEnabled = true
            self.addTouchBarNextButton()
        }


        return true
    }

    func tableView(_ tableView: NSTableView, selectNextRow currentRow: Int) {
        let nextRow = currentRow + 1
        if self.tableView(tableView, shouldSelectRow: nextRow) {
            self.tableView?.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        }
    }

    func tableView(_ tableView: NSTableView, didDeselectAllRows: Bool) {
        if(didDeselectAllRows) {
            nextButton?.isEnabled = false
            nextButton?.title = "Next"

            self.removeTouchBarNextButton()
        }
    }

    @objc public func openInstaller() {
        PageController.shared.dismissPageController()
        let storyboard = NSStoryboard(name: "OSInstall", bundle: Bundle.main)

        if let selectedInstaller = ItemRepository.shared.selectedInstaller,
            let installWindow = storyboard.instantiateController(withIdentifier: "OSInstallWindow") as? OSInstallWindow {
            installWindow.chosenInstaller = selectedInstaller
            installWindow.showWindow(self)

            DDLogVerbose("Opened installer \(selectedInstaller.installerPath)")
        } else if ItemRepository.shared.selectedInstaller == nil {
            DDLogError("No installer was selected")
        } else {
            DDLogError("Could not open installer \(String(describing: ItemRepository.shared.selectedInstaller))")
        }
    }

    private func showFinishPage(volumeName: String, preformatted: Bool = false) {
        PageController.shared.goToFinishPage(finishedText: "Erase Completed", descriptionText: "Please use the \(preformatted ? volumeName : "disk \"\(volumeName)\"") when installing macOS.", otherButtonTitle: "Open Installer", otherButtonSelector: #selector(DiskSelectionViewController.openInstaller), otherButtonSelectorTarget: self)
    }

    @IBAction func nextButtonClicked(_ sender: NSButton) {
        PeerCommunicationService.instance.updateStatus("Erasing Disk")
        if let disk = self.selectedDisk, let containerDisk = self.selectedDiskContainer {

            let userConfirmedErase = self.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(containerDisk.volumeName) (\(disk.deviceID))? This will make all the data on \(containerDisk.volumeName) unrecoverable.")

            if (userConfirmedErase) {
                PageController.shared.goToLoadingPage(loadingText: "Erasing Disk \"\(containerDisk.volumeName)\"", cancelButtonIdentifier: "cancelErase")
                sender.isEnabled = false

                SwiftDisks.safeMode = false
                SwiftDisks.eraseDisk(disk, useAPFS: true, name: "Macintosh HD") { (result) in
                    if result.didSucceed, let volumeName = result.newVolumeName {
                        DispatchQueue.main.async {
                            self.showFinishPage(volumeName: volumeName)
                        }
                    }
                }
            }
        }
        
        #if DEBUG
            self.showFinishPage(volumeName: "None")
        #endif
    }
}

extension DiskSelectionViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.disks.count
    }
}


extension DiskSelectionViewController: NSTouchBarDelegate {
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self

        if PageController.shared.isInitialPage(self) {
            touchBar.defaultItemIdentifiers = [.closeCurrentWindow]
        } else {
            touchBar.defaultItemIdentifiers = [.backPageController]
        }

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        case NSTouchBarItem.Identifier.closeCurrentWindow:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSStopProgressTemplate")!, target: self, action: #selector(backButtonClicked(_:)))
            return item

        case NSTouchBarItem.Identifier.backPageController:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGoBackTemplate")!, target: self, action: #selector(backButtonClicked(_:)))
            return item

        case NSTouchBarItem.Identifier.nextPageController:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGoForwardTemplate")!, target: self, action: #selector(nextButtonClicked(_:)))
            return item

        default: return nil
        }
    }
}
