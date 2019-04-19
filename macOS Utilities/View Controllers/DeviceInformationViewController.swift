//
//  DeviceInformationViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class DeviceInformationViewController: NSViewController {
    @IBOutlet weak var configurationImage: NSImageView?
    @IBOutlet weak var skuHintLabel: NSTextField?
    @IBOutlet weak var disksAndPartitionsTableView: NSTableView?
    @IBOutlet weak var graphicsCardTableView: NSTableView?
    @IBOutlet weak var otherSpecsLabel: NSTextField?

    private var machineInformation: MachineInformation? = nil {
        didSet {
            self.updateView()
        }
    }

    private var allDiskAndPartitions = [Any]() {
        didSet {
            self.reloadTableView(self.disksAndPartitionsTableView)
        }
    }

    private var allGraphicsCards = [String]() {
        didSet {
            self.reloadTableView(self.graphicsCardTableView)
        }
    }

    private func reloadTableView(_ tableView: NSTableView?) {
        if tableView == self.disksAndPartitionsTableView,
            let _tableView = self.disksAndPartitionsTableView {
            DispatchQueue.main.async {
                _tableView.reloadData()
            }
        }

        if tableView == self.graphicsCardTableView,
            let _tableView = self.graphicsCardTableView {
            DispatchQueue.main.async {
                _tableView.reloadData()
            }
        }
    }

    private func hideLabels() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.configurationImage?.animator().alphaValue = 0.0
            }

            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.skuHintLabel?.animator().alphaValue = 0.0
            }

            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.otherSpecsLabel?.animator().alphaValue = 0.0
            }
        }
    }

    private func showLabels() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.configurationImage?.animator().alphaValue = 1.0
            }

            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.skuHintLabel?.animator().alphaValue = 1.0
            }

            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.otherSpecsLabel?.animator().alphaValue = 1.0
            }
        }
    }

    @objc private func updateView() {
        if let machineInformation = self.machineInformation {
            self.hideLabels()
            configurationImage?.image = machineInformation.productImage
            skuHintLabel?.stringValue = machineInformation.displayName
            otherSpecsLabel?.stringValue = "\(machineInformation.RAM) GB of RAM - \(machineInformation.CPU)"

            allGraphicsCards = machineInformation.allGraphicsCards
            allDiskAndPartitions = machineInformation.allDisksAndPartitions

            self.showLabels()
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        if MachineInformation.isConfigured {
            self.machineInformation = MachineInformation.shared
        } else {
            MachineInformation.setup()
            self.machineInformation = MachineInformation.shared
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateView), name: ItemRepository.newPartition, object: nil)
    }

    @IBAction func openSerialLink(_ sender: NSButton) {
        if let machineInformation = self.machineInformation {
            machineInformation.openWarrantyLink()
        }
    }
}
extension DeviceInformationViewController: NSTableViewDelegate, NSTableViewDelegateDeselectListener {
    fileprivate enum CellIdentifiers {
        static let DiskNameCell = "DiskNameID"
        static let DiskSizeCell = "DiskSizeID"
        static let GPUNameCell = "GPUNameID"
        static let PartitionNameCell = "PartitionNameID"
        static let PartitionSizeCell = "PartitionSizeID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        if tableView == self.disksAndPartitionsTableView {
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
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
                    cell.textField?.stringValue = text
                    return cell
                }
            }
        } else if tableView == graphicsCardTableView {
            let GPU = self.allGraphicsCards[row]

            text = GPU
            cellIdentifier = CellIdentifiers.GPUNameCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    @objc func closeWindow(){
        if let window = self.view.window{
            window.close()
        }
    }
}

extension DeviceInformationViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.disksAndPartitionsTableView {
            return allDiskAndPartitions.count
        }
        return allGraphicsCards.count
    }
}

@available(OSX 10.12.1, *)
extension DeviceInformationViewController: NSTouchBarDelegate {
    
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.closeCurrentWindow]
        
        return touchBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier ) -> NSTouchBarItem? {
        switch identifier {
            
        case NSTouchBarItem.Identifier.closeCurrentWindow:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSStopProgressTemplate")!, target: self, action: #selector(closeWindow))
            return item
            
        default: return nil
        }
    }
}
