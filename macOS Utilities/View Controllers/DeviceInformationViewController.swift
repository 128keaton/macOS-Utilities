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
    @IBOutlet weak var serialNumberLabel: NSTextField?

    private var objectsToModify = [Optional<NSControl>]()
    private var isShowingFullSerial = false

    private var machineInformation: MachineInformation? = nil {
        didSet {
            if self.machineInformation != nil {
                self.updateView()
            }
        }
    }

    private var allGraphicsCards = [String]() {
        didSet {
            if self.allGraphicsCards.count > 0 {
                self.reloadTableView(self.graphicsCardTableView)
            }
        }
    }

    @objc private func reloadTableView(_ tableView: NSTableView?) {
        if let aTableView = tableView {
            if aTableView == self.disksAndPartitionsTableView,
                let _tableView = self.disksAndPartitionsTableView {
                DispatchQueue.main.async {
                    _tableView.reloadData()
                }
            }

            if aTableView == self.graphicsCardTableView,
                let _tableView = self.graphicsCardTableView {
                DispatchQueue.main.async {
                    _tableView.reloadData()
                }
            }
        } else if let disksAndPartitionsTableView = self.disksAndPartitionsTableView {
            DispatchQueue.main.async {
                disksAndPartitionsTableView.reloadData()
            }
        }
    }

    private func showLabels() {
        for object in objectsToModify {
            object?.show()
        }
    }

    @objc private func updateView() {
        if let machineInformation = self.machineInformation {
            configurationImage?.image = machineInformation.productImage
            skuHintLabel?.stringValue = machineInformation.displayName
            serialNumberLabel?.stringValue = "Serial Number: \(machineInformation.anonymisedSerialNumber)"


            if configurationImage?.image == NSImage(named: "NSAppleIcon") {
                if #available(OSX 10.14, *) {
                    configurationImage?.contentTintColor = .gray
                } else {
                    configurationImage?.image = NSImage(named: "NSAppleIcon")!.tint(color: .gray)
                }
            }

            machineInformation.getCPU { (CPU) in
                DispatchQueue.main.async {
                    self.otherSpecsLabel?.stringValue = "\(machineInformation.RAM) of RAM - \(CPU.condensed)"
                }
            }

            allGraphicsCards = machineInformation.allGraphicsCards
            self.showLabels()
        }
    }

    @objc func toggleFullSerial() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.serialNumberLabel?.animator().alphaValue = 0.0
        }

        if let machineInformation = self.machineInformation {
            if isShowingFullSerial == true {
                isShowingFullSerial = false
                serialNumberLabel?.stringValue = "Serial Number: \(machineInformation.anonymisedSerialNumber)"
            } else {
                isShowingFullSerial = true
                serialNumberLabel?.stringValue = "Serial Number: \(machineInformation.serialNumber)"
            }
        }

        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.serialNumberLabel?.animator().alphaValue = 1.0
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        objectsToModify = [configurationImage, skuHintLabel, otherSpecsLabel, serialNumberLabel]

        if MachineInformation.isConfigured {
            self.machineInformation = MachineInformation.shared
        } else if let currentPreferences = PreferenceLoader.currentPreferences,
            currentPreferences.useDeviceIdentifierAPI {
            MachineInformation.setup()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.machineInformation = MachineInformation.shared
            }
        }

        let serialClickHandler = NSClickGestureRecognizer(target: self, action: #selector(toggleFullSerial))
        self.serialNumberLabel?.addGestureRecognizer(serialClickHandler)

        self.graphicsCardTableView?.sizeToFit()
        self.disksAndPartitionsTableView?.sizeToFit()

        self.reloadTableView(disksAndPartitionsTableView)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableView(_:)), name: GlobalNotifications.newDisks, object: nil)
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
        static let GPUMetalStatusCell = "GPUMetalStatusID"
        static let PartitionNameCell = "PartitionNameID"
        static let PartitionSizeCell = "PartitionSizeID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""
        var textFieldColor: NSColor? = nil
        var image: NSImage? = nil

        if tableView == self.disksAndPartitionsTableView {
            let fileSystemItem = DiskUtility.allDisksWithPartitions[row]
            if fileSystemItem.itemType == .disk {
                let disk = fileSystemItem as! Disk

                if tableColumn == tableView.tableColumns[0] {
                    text = disk.partitions.count == 0 ? "\(disk.deviceIdentifier) - (no partitions)" : disk.deviceIdentifier
                    textFieldColor = disk.partitions.count == 0 ? NSColor.tertiaryLabelColor : nil

                    cellIdentifier = CellIdentifiers.DiskNameCell
                } else if tableColumn == tableView.tableColumns[1] {
                    text = disk.size.getReadableUnit()
                    cellIdentifier = CellIdentifiers.DiskSizeCell
                }

            } else if fileSystemItem.itemType == .partition {
                let partition = fileSystemItem as! Partition

                if tableColumn == tableView.tableColumns[0] {
                    text = partition.volumeName != "Not mounted" ? partition.volumeName : partition.deviceIdentifier
                    textFieldColor = partition.rawVolumeName == nil ? NSColor.tertiaryLabelColor : nil
                    cellIdentifier = CellIdentifiers.PartitionNameCell
                } else if tableColumn == tableView.tableColumns[1] {
                    text = partition.size.getReadableUnit()
                    cellIdentifier = CellIdentifiers.PartitionSizeCell
                }
            }
        } else if tableView == graphicsCardTableView {
            let GPU = self.allGraphicsCards[row]

            if tableColumn == tableView.tableColumns[0] {
                text = GPU
                cellIdentifier = CellIdentifiers.GPUNameCell
            } else if tableColumn == tableView.tableColumns[1] {
                image = MachineInformation.shared.graphicsCardIsMetal(GPU) ? NSImage(named: "NSStatusAvailable")! : NSImage(named: "NSStatusUnavailable")!
                cellIdentifier = CellIdentifiers.GPUMetalStatusCell
            }
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            if let cellImage = image {
                cell.imageView?.image = cellImage
            }

            if let textColor = textFieldColor {
                cell.textField?.textColor = textColor
            }

            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }

    @objc func closeWindow() {
        if let window = self.view.window {
            window.close()
        }
    }
}

extension DeviceInformationViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.disksAndPartitionsTableView {
            return DiskUtility.allDisksWithPartitions.count
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

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        case NSTouchBarItem.Identifier.closeCurrentWindow:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSStopProgressTemplate")!, target: self, action: #selector(closeWindow))
            return item

        default: return nil
        }
    }
}
