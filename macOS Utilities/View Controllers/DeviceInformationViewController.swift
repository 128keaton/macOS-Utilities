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

    private var deviceInfo: DeviceInfo? = nil {
        didSet {
            DispatchQueue.main.async {
                self.updateView()
            }
        }
    }

    private var allVolumes = [Volume]() {
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

    private func getVolumes() {
        allVolumes = ItemRepository.shared.getDisks().filter { $0.getMainVolume() !== nil }.map { $0.getMainVolume()! }.filter { $0.containsInstaller == false && $0.isValid == true }
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

    override func viewDidLoad() {
        super.viewDidLoad()

        if deviceInfo == nil {
            configurationImage?.alphaValue = 0.0
            skuHintLabel?.alphaValue = 0.0
        } else {
            configurationImage?.alphaValue = 1.0
            skuHintLabel?.alphaValue = 1.0
        }

        DeviceIdentifier.shared.lookupAppleSerial(serialNumber!) { (deviceInfo) in
            self.deviceInfo = deviceInfo
        }

        getVolumes()
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
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        let volume = allVolumes[row]

        let size = volume.size
        let measurementUnit = volume.measurementUnit
        let name = volume.volumeName

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
        return false
    }
}

extension DeviceInformationViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return allVolumes.count
    }
}
