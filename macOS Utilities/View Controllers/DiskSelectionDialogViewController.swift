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

    private var installableDisks = [MountedDisk]()
    private let diskUtility = DiskUtility.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        getDisks()
    }

    private func getDisks() {
        diskUtility.getAllDisks(mountedOnly: true) { (physicalDisks) in
            self.installableDisks = physicalDisks.map { $0.mountedDisk! }.filter { $0.isInstallable == true }
            self.tableView?.reloadData()
        }
    }
    
    @IBAction func openDiskUtility(_ sender: NSButton) {
        Application.open("Disk Utility", isUtility: true)
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

        let installableDisk = installableDisks[row]

        if tableColumn == tableView.tableColumns[0] {
            text = installableDisk.name
            cellIdentifier = CellIdentifiers.DiskNameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = "\(Int(installableDisk.size.rounded())) \(installableDisk.measurementUnit)"
            cellIdentifier = CellIdentifiers.DiskSizeCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
}

extension DiskSelectionDialogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return installableDisks.count
    }
}
