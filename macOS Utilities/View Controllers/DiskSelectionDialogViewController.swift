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
    
    private var installableDisks = [Disk]()
    private let diskUtility = DiskUtility.shared

    private var selectedDisk: Disk? = nil


    override func viewDidLoad() {
        super.viewDidLoad()
        getDisks()
    }

    private func getDisks() {
        installableDisks = ItemRepository.shared.getDisks().filter { $0.isInstallable == true && $0.getMainVolume() != nil && $0.getMainVolume()!.isInstallable == true}
        self.tableView?.reloadData()
    }

    @IBAction func openDiskUtility(_ sender: NSButton) {
        ApplicationUtility.shared.open("Disk Utility")
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
        
        var size = installableDisk.size
        var measurementUnit = installableDisk.measurementUnit
        var name = installableDisk.deviceIdentifier
        
        if let installableVolume = installableDisk.getMainVolume(){
            size = installableVolume.size
            measurementUnit = installableVolume.measurementUnit
            name = installableVolume.volumeName
        }

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
        print("Disk Selected: \(self.installableDisks[row])")
        self.selectedDisk = self.installableDisks[row]
        nextButton?.isEnabled = true

        return true
    }

    override open func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        let point = self.view.convert(event.locationInWindow, from: nil)
        let rowIndex = tableView?.row(at: point)

        if rowIndex! < 0 { // We didn't click any row
            tableView?.deselectAll(nil)
            self.selectedDisk = nil
            nextButton?.isEnabled = false
        }
    }

    @IBAction func nextButtonClicked(_ sender: NSButton) {
        if let disk = self.selectedDisk {
            spinnyView?.startSpinning()
            sender.isEnabled = false
            /*diskUtility.erase(disk: disk, newName: disk.mountedDisk!.name) { (didFinish) in
                DiskRepository.shared.getSelectedInstaller(returnCompletion: { (potentialInstaller) in
                    if let selectedInstaller = potentialInstaller {
                        selectedInstaller.launch()
                        DispatchQueue.main.sync {
                            self.spinnyView?.stopSpinning()
                            self.dismiss(self)
                        }
                    }
                })
            }*/
        }
    }
}

extension DiskSelectionDialogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return installableDisks.count
    }
}
