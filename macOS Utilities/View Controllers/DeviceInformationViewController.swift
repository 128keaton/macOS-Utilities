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
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var gpuTableView: NSTableView?
    @IBOutlet weak var otherSpecsLabel: NSTextField?

    private var deviceInfo: DeviceInfo? = nil {
        didSet {
            DispatchQueue.main.async {
                self.updateView()
            }
        }
    }

    private var allDiskAndPartitions = [Any]() {
        didSet {
            self.tableView?.reloadData()
        }
    }

    private var GPUs = [String]() {
        didSet {
            reloadTableView()
        }
    }

    private func reloadTableView() {
        if let _tableView = self.tableView {
            DispatchQueue.main.async {
                _tableView.reloadData()
            }
        }
    }


    private var serialNumber: String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

        guard platformExpert > 0 else {
            return nil
        }

        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
            return nil
        }

        IOObjectRelease(platformExpert)
        return serialNumber
    }

    private func getAllData() {
        GPUs = Compatibility().getAllGPUs()
        getPartitions()
    }

    @objc func getPartitions() {
        allDiskAndPartitions = DiskUtility.shared.getAllDisksAndPartitions()
    }

    private func updateView() {
        if let deviceInfo = self.deviceInfo {
            configurationImage?.image = deviceInfo.configurationCode.image
            skuHintLabel?.stringValue = deviceInfo.configurationCode.skuHint
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.configurationImage?.animator().alphaValue = 1.0
            }
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.skuHintLabel?.animator().alphaValue = 1.0
            }
        }
    }

    override func viewDidAppear() {
        self.getPartitions()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(getPartitions), name: ItemRepository.newPartition, object: nil)

        if deviceInfo == nil {
            configurationImage?.alphaValue = 0.0
            skuHintLabel?.alphaValue = 0.0
        } else {
            configurationImage?.alphaValue = 1.0
            skuHintLabel?.alphaValue = 1.0
        }

        let amountOfRAM = Units(bytes: Int64(ProcessInfo.processInfo.physicalMemory))

        otherSpecsLabel?.stringValue = "\(amountOfRAM) of RAM"

        TaskHandler.createTask(command: "/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"]) { (cpuInfo) in
            if let cpuModel = cpuInfo {
                DispatchQueue.main.async {
                    self.otherSpecsLabel?.stringValue = "\(self.otherSpecsLabel!.stringValue) - \(cpuModel)"
                }
            }
        }

        DeviceIdentifier.shared.lookupAppleSerial(serialNumber!) { (deviceInfo) in
            self.deviceInfo = deviceInfo
        }

        getAllData()
    }

    @IBAction func openSerialLink(_ sender: NSButton) {
        if let coverageURL = deviceInfo?.coverageURL {
            NSWorkspace().open(coverageURL)
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

        if tableView == self.tableView {
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
        } else if tableView == gpuTableView {
            let GPU = self.GPUs[row]

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
}

extension DeviceInformationViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.tableView {
            return allDiskAndPartitions.count
        }
        return GPUs.count
    }
}
