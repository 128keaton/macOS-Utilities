//
//  DeviceInformationViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack
import Quartz

class DeviceInformationViewController: NSViewController {
    @IBOutlet weak var configurationImage: NSHidingButton!
    @IBOutlet weak var configurationCodeLabel: NSTextField!
    @IBOutlet weak var disksAndPartitionsTableView: NSTableView!
    @IBOutlet weak var graphicsCardTableView: NSTableView!
    @IBOutlet weak var otherSpecsLabel: NSTextField!
    @IBOutlet weak var serialNumberLabel: NSTextField!

    private var objectsToModify = [Optional<NSControl>]()
    private var isShowingFullSerial = false
    private var progressIndicator: NSProgressIndicator? = nil
    private var barcodeURL: URL? = nil

    private var allGraphicsCards = [String]() {
        didSet {
            if self.allGraphicsCards.count > 0 {
                self.reloadTableView(self.graphicsCardTableView)
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        PeerCommunicationService.instance.updateStatus("Viewing Info")
        if SystemProfiler.hasMachineData && barcodeURL == nil {
            saveBarcode()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        if let validBarcodeURL = barcodeURL {
            do {
                try FileManager.default.removeItem(at: validBarcodeURL)
                barcodeURL = nil
            } catch {
                DDLogVerbose("Could not delete barcode item..ignoring")
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

    @IBAction func showQuickLookPanel(sender: AnyObject) {
        if let panel = QLPreviewPanel.shared() {
            panel.makeKeyAndOrderFront(self)
        }
    }

    private func showObjects(exceptObjects: [Optional<NSControl>] = []) {
        removeProgressIndicator()
        for objectToShow in objectsToModify {
            if !exceptObjects.contains(objectToShow) {
                objectToShow?.show()
            }

            if objectToShow == configurationImage {
                configurationImage.shake(duration: 0.4, delay: 0.2)
            }
        }
    }

    private func hideObjects(animated: Bool = true) {
        createProgressIndicator()
        for objectToHide in objectsToModify {
            objectToHide?.hide(animated: animated)
        }
    }

    private func saveBarcode() {
        DispatchQueue.main.async {
            self.barcodeURL = FileManager.default.writeImageToTemporaryDirectory(image: SystemProfiler.barcodeImage, resourceName: SystemProfiler.serialNumber, fileExtension: "png")
        }
    }

    @objc private func updateView() {
        if SystemProfiler.hasMachineData {
            saveBarcode()

            configurationImage.image = SystemProfiler.barcodeImage
            serialNumberLabel.stringValue = "Serial Number: \(SystemProfiler.anonymisedSerialNumber)"

            if configurationImage.image == NSImage(named: "NSAppleIcon") {
                if #available(OSX 10.14, *) {
                    configurationImage.contentTintColor = .gray
                } else {
                    configurationImage.image = NSImage(named: "NSAppleIcon")!.tint(color: .gray)
                }
            } else {
                configurationImage.layer?.cornerRadius = 4.0
                configurationImage.layer?.masksToBounds = true
            }

            SerialNumberMatcher.matchToProductName(SystemProfiler.serialNumber) { (configurationCode) in
                self.configurationCodeLabel.stringValue = configurationCode
                self.configurationCodeLabel.sizeToFitText(minimumFontSize: 22, fontWeight: .semibold)
                self.configurationCodeLabel.show()
            }

            otherSpecsLabel.stringValue = "\(SystemProfiler.amountOfMemoryInstalled) GB of RAM - \(SystemProfiler.processorInformation)"
            allGraphicsCards = SystemProfiler.displayItems.map { $0.graphicsCardModel }
            self.showObjects(exceptObjects: [configurationCodeLabel])
        }
    }

    @objc func toggleFullSerial() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.serialNumberLabel.animator().alphaValue = 0.0
        }

        if isShowingFullSerial == true {
            isShowingFullSerial = false
            serialNumberLabel.stringValue = "Serial Number: \(SystemProfiler.anonymisedSerialNumber)"
        } else {
            isShowingFullSerial = true
            serialNumberLabel.stringValue = "Serial Number: \(SystemProfiler.serialNumber)"
        }

        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.serialNumberLabel.animator().alphaValue = 1.0
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        objectsToModify = [configurationImage, configurationCodeLabel, otherSpecsLabel, serialNumberLabel]
        hideObjects(animated: false)

        SystemProfiler.delegate = self
        SystemProfiler.getInfo()

        let serialClickHandler = NSClickGestureRecognizer(target: self, action: #selector(toggleFullSerial))
        self.serialNumberLabel.addGestureRecognizer(serialClickHandler)

        self.graphicsCardTableView.sizeToFit()
        self.disksAndPartitionsTableView.sizeToFit()

        self.reloadTableView(disksAndPartitionsTableView)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableView(_:)), name: GlobalNotifications.newDisks, object: nil)
    }

    private func createProgressIndicator() {
        if progressIndicator == nil {
            let size: CGFloat = 18.0
            let xValue = (self.view.frame.width / 2.0) - (size / 2.0)
            let yValue: CGFloat = 390.0

            progressIndicator = NSProgressIndicator(frame: NSRect(x: xValue, y: yValue, width: size, height: size))
            progressIndicator?.style = .spinning
            progressIndicator?.startSpinning()

            self.view.addSubview(progressIndicator!)
        }
    }

    private func removeProgressIndicator() {
        if let _progressIndicator = self.progressIndicator {
            _progressIndicator.removeFromSuperview()
            self.progressIndicator = nil
        }
    }
}

extension DeviceInformationViewController: QLPreviewPanelDataSource {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        if let validBarcodeURL = barcodeURL {
            let newPreviewItem = KBBarcodePreviewItem()
            newPreviewItem.previewItemURL = validBarcodeURL
            newPreviewItem.previewItemTitle = SystemProfiler.serialNumber
            return newPreviewItem
        }

        return nil
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        DDLogVerbose("Barcode QLPanel has dissapeared..")
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QLPreviewPanel.shared()?.delegate = self
        QLPreviewPanel.shared()?.dataSource = self
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
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
                image = SystemProfiler.graphicsCardIsMetalCapable(graphicsCardModel: GPU) ? NSImage(named: "NSStatusAvailable")! : NSImage(named: "NSStatusUnavailable")!
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

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCoverageViewController" {
            let checkCoverageViewController = segue.destinationController as! CheckCoverageViewController
            var warrantyLink: URL? = nil

            if !SystemProfiler.serialNumber.contains(SystemProfiler.modelIdentifier) {
                warrantyLink = URL(string: "https://checkcoverage.apple.com/?sn=\(SystemProfiler.serialNumber)")
            }

            guard let validWarrantyLink = warrantyLink else {
                KBLogDebug("Could not generate warranty link. Object was nil.")
                return
            }

            checkCoverageViewController.urlToOpen = validWarrantyLink
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

@available(OSX 10.12.2, *)
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

extension DeviceInformationViewController: SystemProfilerDelegate {
    func dataParsedSuccessfully() {
        self.updateView()
    }

    func handleError(_ error: Error) {
        KBLogDebug(error.localizedDescription)
    }
}
