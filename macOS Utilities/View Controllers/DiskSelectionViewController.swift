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

class DiskSelectionViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var nextButton: NSButton?
    @IBOutlet weak var diskProgressIndicator: NSProgressIndicator?
    @IBOutlet weak var installingVersionLabel: NSTextField?
    @IBOutlet weak var backButton: NSButton!

    private let diskUtility = DiskUtility.shared
    private var defaultItemIdentifiers: [NSTouchBarItem.Identifier] = [.backPageController]

    private var selectedInstaller: Installer? = nil
    private var selectedPartition: Partition? = nil
    private var selectedDisk: Disk? = nil

    private var alreadyAppeared = false

    // MARK: Superclass overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        self.diskProgressIndicator?.stopSpinning()
        updateBackButton()
        getSelectedInstaller()

        NotificationCenter.default.addObserver(self, selector: #selector(handleCancelButtonFromLoadingPage(_:)), name: WizardViewController.cancelButtonNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(newDisksHandler), name: DiskUtility.newDisks, object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateBackButton()
        getSelectedInstaller()

        if !alreadyAppeared {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkAndAskAboutFusionDrive()
            }
        }

        alreadyAppeared = true
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        self.reloadTableView()
        updateBackButton()
    }

    // MARK: Button actions
    @IBAction @objc func openDiskUtility(_ sender: NSButton) {
        NotificationCenter.default.post(name: ItemRepository.openApplication, object: "Disk Utility")
    }

    @IBAction @objc func backButtonClicked(_ sender: NSButton) {
        if PageController.shared.isInitialPage(self) {
            PageController.shared.dismissPageController()
        } else {
            PageController.shared.goToPreviousPage()
        }
    }

    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        diskUtility.getAllDisks()
        self.checkAndAskAboutFusionDrive()
    }

    @objc func newDisksHandler() {
        reloadTableView()
    }

    @objc func handleCancelButtonFromLoadingPage(_ notification: Notification) {
        if let cancelID = notification.object as? String,
            cancelID == "cancelErase" {

            var itemName = ""

            if let validPartition = self.selectedPartition {
                itemName = "partition \(validPartition.volumeName)"
            } else if let validDisk = self.selectedDisk {
                itemName = "disk \(validDisk.deviceIdentifier)"
            }

            if let currentTask = TaskHandler.lastTask,
                currentTask.isRunning {
                currentTask.terminate()
            }

            if showConfirmationAlert(question: "Do you want to continue?", text: "You have cancelled the erase on \"\(itemName)\". Do you want to continue with install?") {
                self.showFinishPage(volumeName: itemName, preformatted: true)
            } else {
                PageController.shared.dismissPageController()
            }
        }
    }

    // MARK: Functions
    private func checkAndAskAboutFusionDrive() {
        let disks = diskUtility.allDisksWithPartitions.filter { $0.itemType == .disk } as! [Disk]
        let disksWithInfo = disks.filter { $0.info != nil }
        let disksPotentiallyFusionParts = disksWithInfo.filter { $0.info!.potentialFusionDriveHalve }

        if disksPotentiallyFusionParts.count <= 1 {
            DDLogVerbose("Internal Drives: \(disksPotentiallyFusionParts)")
            DDLogVerbose("The reported number of internal drives (\(disksPotentiallyFusionParts.count)) was less than two, therefore no Fusion Drive.")
            //             return
        }

        if (disksWithInfo.filter { $0.info!.isSolidState == true }).count == 0 {
            DDLogVerbose("There weren't any non-hard disk drives, therefore no Fusion Drive.")
            //               return
        }

        // Check for an HDD
        if (disksWithInfo.filter { $0.info!.isSolidState == false }).count == 0 {
            DDLogVerbose("There weren't any non-solid state drives, therefore no Fusion Drive.")
            //        return
        }

        self.showConfirmationAlert(question: "Repair Fusion Drive?", text: "A potential Fusion Drive has been detected, do you want to try and repair it?", window: self.view.window!) { (modalResponse) in
            if modalResponse == .alertFirstButtonReturn {
                PageController.shared.goToLoadingPage(loadingText: "Repairing..", cancelButtonIdentifier: "repairFusionDrive")
                self.diskUtility.createFusionDrive { (message, didCreate) in
                    if didCreate {
                        DDLogVerbose(message)
                        self.showFinishPage(volumeName: "Macintosh HD")
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
            touchBar.defaultItemIdentifiers = self.defaultItemIdentifiers
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

        let fileSystemItem = diskUtility.installableDisksWithPartitions[row]

        if fileSystemItem.itemType == .disk {
            let disk = fileSystemItem as! Disk
            if tableColumn == tableView.tableColumns[0] {
                text = disk.deviceIdentifier
                cellIdentifier = CellIdentifiers.DiskNameCell
            } else if tableColumn == tableView.tableColumns[1] {
                text = disk.size.getReadableUnit()
                cellIdentifier = CellIdentifiers.DiskSizeCell
            }
        } else if fileSystemItem.itemType == .partition {
            let partition = fileSystemItem as! Partition
            if tableColumn == tableView.tableColumns[0] {
                text = partition.volumeName
                cellIdentifier = CellIdentifiers.PartitionNameCell
            } else if tableColumn == tableView.tableColumns[1] {
                text = partition.size.getReadableUnit()
                cellIdentifier = CellIdentifiers.PartitionSizeCell
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

        let fileSystemItem = diskUtility.installableDisksWithPartitions[row]

        DDLogVerbose("Disk/Partition Selected: \(fileSystemItem)")

        if fileSystemItem.itemType == .disk {
            self.selectedPartition = nil
            self.selectedDisk = (fileSystemItem as! Disk)

            if diskUtility.installableDisksWithPartitions.indices.contains(row + 1),
                let nextItem = diskUtility.installableDisksWithPartitions[row + 1] as? Partition,
                let selectedDiskPartition = self.selectedDisk?.installablePartition,
                selectedDiskPartition == nextItem {
                self.tableView(tableView, selectNextRow: row)
                return false
            }
        } else if fileSystemItem.itemType == .partition {
            self.selectedDisk = nil
            self.selectedPartition = (fileSystemItem as! Partition)
        }

        if let selectedInstaller = self.selectedInstaller {
            if let selectedDisk = self.selectedDisk {
                if !DiskUtility.diskIsFormattedFor(selectedDisk, installer: selectedInstaller) {
                    nextButton?.title = "Reformat"
                } else {
                    nextButton?.title = "Next"
                }
            } else if let selectedPartition = self.selectedPartition {
                if !DiskUtility.partitionIsFormattedFor(selectedPartition, installer: selectedInstaller) {
                    nextButton?.title = "Reformat"
                } else {
                    nextButton?.title = "Next"
                }
            }
        }

        nextButton?.isEnabled = true
        self.addTouchBarNextButton()

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
            selectedPartition = nil
            self.removeTouchBarNextButton()
        }
    }

    @objc public func openInstaller() {
        PageController.shared.dismissPageController()

        if let selectedInstaller = ItemRepository.shared.selectedInstaller,
            selectedInstaller.open() {
            DDLogVerbose("Opened installer \(selectedInstaller)")
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
        if let selectedInstaller = self.selectedInstaller {
            if let partition = self.selectedPartition {
                let volumeName = partition.volumeName
                let userConfirmedErase = self.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(volumeName)? This will make all the data on \(volumeName) unrecoverable.")

                if(userConfirmedErase) {
                    PageController.shared.goToLoadingPage(loadingText: "Erasing Disk \"\(volumeName)\"", cancelButtonIdentifier: "cancelErase")
                    sender.isEnabled = false

                    partition.erase(newName: nil, forInstaller: selectedInstaller) { (didFinish, newVolumeName) in
                        if(didFinish), let volumeName = newVolumeName {
                            self.showFinishPage(volumeName: volumeName)
                        }
                    }

                }
            } else if let disk = self.selectedDisk, disk.canErase {
                let deviceIdentifier = disk.deviceIdentifier
                PageController.shared.goToLoadingPage(loadingText: "Erasing Disk \"\(deviceIdentifier)\"", cancelButtonIdentifier: "cancelErase")
                sender.isEnabled = false

                disk.erase(newName: nil, forInstaller: selectedInstaller) { (didFinish, newDiskName) in
                    if(didFinish), let diskName = newDiskName {
                        self.showFinishPage(volumeName: diskName)
                    }
                }
            }
        }
    }
}

extension DiskSelectionViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return diskUtility.installableDisksWithPartitions.count
    }
}

@available(OSX 10.12.1, *)
extension DiskSelectionViewController: NSTouchBarDelegate {
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self

        if PageController.shared.isInitialPage(self) {
            self.defaultItemIdentifiers = [.closeCurrentWindow]
        } else {
            self.defaultItemIdentifiers = [.backPageController]
        }

        touchBar.defaultItemIdentifiers = self.defaultItemIdentifiers
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
