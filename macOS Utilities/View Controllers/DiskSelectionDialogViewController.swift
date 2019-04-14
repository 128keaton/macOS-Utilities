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
    private var installableVolumes = [Volume]() {
        didSet {
            reloadTableView()
        }
    }
    private var selectedVolume: Volume? = nil

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
        installableVolumes = ItemRepository.shared.getDisks().filter { $0.isInstallable == true && $0.getMainVolume() != nil && $0.getMainVolume()!.isInstallable == true }.map { $0.getMainVolume()! }
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
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        let installableVolume = installableVolumes[row]

        let size = installableVolume.size
        let measurementUnit = installableVolume.measurementUnit
        let name = installableVolume.volumeName

        if tableColumn == tableView.tableColumns[0] {
            text = name
            cellIdentifier = CellIdentifiers.DiskNameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = "\(Int(size)) \(measurementUnit)"
            cellIdentifier = CellIdentifiers.DiskSizeCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        self.tableView?.deselectAll(self)
        DDLogInfo("Disk Selected: \(self.installableVolumes[row])")
        self.selectedVolume = self.installableVolumes[row]
        nextButton?.isEnabled = true

        return true
    }

    func tableView(_ tableView: NSTableView, didDeselectAllRows: Bool) {
        if(didDeselectAllRows) {
            nextButton?.isEnabled = false
            DDLogInfo("Deselecting all disks/rows in \(self)")
            selectedVolume = nil
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
        if let volume = self.selectedVolume {
            let userConfirmedErase = self.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(volume.volumeName)? This will make all the data on \(volume.volumeName) unrecoverable.")

            if(userConfirmedErase) {
                PageController.shared.goToLoadingPage(loadingText: "Erasing Disk \"\(volume.volumeName)\"")
                sender.isEnabled = false

                diskUtility.erase(volume, newName: volume.volumeName) { (didFinish) in
                    if(didFinish) {
                        PageController.shared.goToFinishPage(finishedText: "Erase Completed", descriptionText: "Please use the disk \"\(volume.volumeName)\" when installing macOS.", otherButtonTitle: "Open Installer", otherButtonSelector: #selector(DiskSelectionDialogViewController.openInstaller), otherButtonSelectorTarget: self)
                    }
                }
            }
        }
    }
}

extension DiskSelectionDialogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return installableVolumes.count
    }
}
