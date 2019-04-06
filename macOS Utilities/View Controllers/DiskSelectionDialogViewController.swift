//
//  DiskSelectionPopupViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class DiskSelectionDialogViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var nextButton: NSButton?
    @IBOutlet weak var spinnyView: NSProgressIndicator?

    private var installableVolumes = [Volume]()
    private let diskUtility = DiskUtility.shared

    private var selectedVolume: Volume? = nil


    override func viewDidLoad() {
        super.viewDidLoad()
        getDisks()
    }

    private func getDisks() {
        installableVolumes = ItemRepository.shared.getDisks().filter { $0.isInstallable == true && $0.getMainVolume() != nil && $0.getMainVolume()!.isInstallable == true }.map { $0.getMainVolume()! }
        self.tableView?.reloadData()
    }

    @IBAction func openDiskUtility(_ sender: NSButton) {
        ApplicationUtility.shared.open("Disk Utility")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension DiskSelectionDialogViewController: NSTableViewDelegate {

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
        print("Disk Selected: \(self.installableVolumes[row])")
        self.selectedVolume = self.installableVolumes[row]
        nextButton?.isEnabled = true

        return true
    }

    override open func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        let point = self.view.convert(event.locationInWindow, from: nil)
        let rowIndex = tableView?.row(at: point)

        if rowIndex! < 0 { // We didn't click any row
            tableView?.deselectAll(nil)
            self.selectedVolume = nil
            nextButton?.isEnabled = false
        }
    }

    @IBAction func nextButtonClicked(_ sender: NSButton) {
        let aUnownedSelf = self
        if let volume = self.selectedVolume {
            let userConfirmedErase = self.showConfirmationAlert(question: "Confirm Disk Destruction", text: "Are you sure you want to erase disk \(volume.volumeName)")
            if(userConfirmedErase) {
                spinnyView?.startSpinning()
                sender.isEnabled = false
                diskUtility.erase(volume, newName: volume.volumeName) { (didFinish) in
                    if(didFinish) {
                        if let selectedInstaller = (ItemRepository.shared.getInstallers().first { $0.isSelected == true }) {
                            selectedInstaller.launch()
                        }

                        OperationQueue.main.addOperation{
                            self.spinnyView?.stopSpinning()
                            self.nextButton?.isEnabled = true
                            aUnownedSelf.view.window?.close()
                            aUnownedSelf.showInfoAlert(title: "Erase Completed", message: "Please use the disk \"\(volume.volumeName)\" when installing macOS.")
                        }
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
