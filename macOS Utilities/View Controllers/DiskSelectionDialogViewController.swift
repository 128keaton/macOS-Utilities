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

class DiskSelectionDialogViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var nextButton: NSButton?
    @IBOutlet weak var diskProgressIndicator: NSProgressIndicator?
    @IBOutlet weak var installingVersionLabel: NSTextField?
    @IBOutlet weak var backButton: NSButton!

    private let diskUtility = DiskUtility.shared

    private var selectedInstaller: Installer? = nil
    private var allDiskAndPartitions = [Any]() {
        didSet {
            self.tableView?.reloadData()
        }
    }

    private var selectedPartition: Partition? = nil
    private var selectedDisk: Disk? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBackButton()
        getSelectedInstaller()
        getDisks()
    }

    private func getSelectedInstaller() {
        if let selectedInstaller = ItemRepository.shared.getSelectedInstaller() {
            installingVersionLabel?.stringValue = "Installing \(selectedInstaller.versionName)"
            installingVersionLabel?.isHidden = false
            self.selectedInstaller = selectedInstaller
        } else {
            installingVersionLabel?.isHidden = true
        }
    }

    private func getDisks() {
        diskProgressIndicator?.startSpinning()
        allDiskAndPartitions = DiskUtility.shared.getAllDisksAndPartitions()
    }

    @IBAction func openDiskUtility(_ sender: NSButton) {
        ApplicationUtility.shared.open("Disk Utility")
    }

    @IBAction func backButtonClicked(_ sender: NSButton) {
        if PageController.shared.isInitialPage(self) {
            PageController.shared.dismissPageController()
        } else {
            PageController.shared.goToPreviousPage()
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

    override func viewWillAppear() {
        updateBackButton()
    }

    private func updateBackButton() {
        if PageController.shared.isInitialPage(self) {
            backButton.title = "Cancel"
        } else {
            backButton.title = "Back"
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateBackButton()
        getSelectedInstaller()
        getDisks()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

extension DiskSelectionDialogViewController: NSTableViewDelegate, NSTableViewDelegateDeselectListener {

    fileprivate enum CellIdentifiers {
        static let DiskNameCell = "DiskNameID"
        static let DiskSizeCell = "DiskSizeID"
        static let PartitionNameCell = "PartitionNameID"
        static let PartitionSizeCell = "PartitionSizeID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        let item = allDiskAndPartitions[row]
        if type(of: item) == Disk.self {
            let disk = item as! Disk

            if tableColumn == tableView.tableColumns[0] {
                text = disk.deviceIdentifier
                cellIdentifier = CellIdentifiers.DiskNameCell
            } else if tableColumn == tableView.tableColumns[1] {
                text = disk.size.getReadableUnit()
                cellIdentifier = CellIdentifiers.DiskSizeCell
            }

        } else if type(of: item) == Partition.self {
            let partition = item as! Partition

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
        DDLogInfo("Disk/Partition Selected: \(self.allDiskAndPartitions[row])")

        let item = allDiskAndPartitions[row]
        if type(of: item) == Disk.self {
            let temporaryDisk = item as? Disk
            if temporaryDisk!.partitions.count > 0 {
                self.tableView(tableView, selectNextRow: row)
                return false
            } else {
                self.selectedDisk = temporaryDisk
                self.selectedPartition = nil
                if !DiskUtility.diskIsFormattedFor(self.selectedDisk!, installer: self.selectedInstaller!) {
                    nextButton?.title = "Reformat"
                } else {
                    nextButton?.title = "Next"
                }
            }
        } else if type(of: item) == Partition.self {
            self.selectedPartition = item as? Partition
            self.selectedDisk = nil
            if !DiskUtility.partitionIsFormattedFor(self.selectedPartition!, installer: self.selectedInstaller!) {
                nextButton?.title = "Reformat"
            } else {
                nextButton?.title = "Next"
            }
        }

        nextButton?.isEnabled = true
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
            DDLogInfo("Deselecting all disks/rows in \(self)")
            selectedPartition = nil
        }
    }

    @objc public func openInstaller() {
        PageController.shared.dismissPageController()

        if let selectedInstaller = self.selectedInstaller {
            selectedInstaller.launch()
        } else if let selectedInstaller = ItemRepository.shared.getSelectedInstaller() {
            selectedInstaller.launch()
        } else {
            DDLogError("Unable to launch installer: no installer selected")
        }
    }

    @IBAction func nextButtonClicked(_ sender: NSButton) {
        if let selectedInstaller = self.selectedInstaller {
            if let partition = self.selectedPartition {
                let volumeName = partition.volumeName
                let userConfirmedErase = self.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(volumeName)? This will make all the data on \(volumeName) unrecoverable.")

                if(userConfirmedErase) {
                    PageController.shared.goToLoadingPage(loadingText: "Erasing Disk \"\(volumeName)\"")
                    sender.isEnabled = false
                    
                    partition.erase(newName: nil, forInstaller: selectedInstaller) { (didFinish, newVolumeName) in
                        if(didFinish), let volumeName = newVolumeName {
                            PageController.shared.goToFinishPage(finishedText: "Erase Completed", descriptionText: "Please use the disk \"\(volumeName)\" when installing macOS.", otherButtonTitle: "Open Installer", otherButtonSelector: #selector(DiskSelectionDialogViewController.openInstaller), otherButtonSelectorTarget: self)
                        }
                    }

                }
            } else if let disk = self.selectedDisk, disk.canErase {
                let deviceIdentifier = disk.deviceIdentifier
                PageController.shared.goToLoadingPage(loadingText: "Erasing Disk \"\(deviceIdentifier)\"")
                sender.isEnabled = false

                disk.erase(newName: nil, forInstaller: selectedInstaller) { (didFinish, newDiskName) in
                    if(didFinish), let diskName = newDiskName {
                        PageController.shared.goToFinishPage(finishedText: "Erase Completed", descriptionText: "Please use the disk \"\(diskName)\" when installing macOS.", otherButtonTitle: "Open Installer", otherButtonSelector: #selector(DiskSelectionDialogViewController.openInstaller), otherButtonSelectorTarget: self)
                    }
                }
            }
        }
    }
}


extension DiskSelectionDialogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return allDiskAndPartitions.count
    }
}
