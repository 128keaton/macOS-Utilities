//
//  PreferencesApplicationsViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/11/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class PreferencesApplicationsViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!

    public var preferencesViewController: PreferencesViewController? = nil

    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "public.data")
    private var fileNameType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")

    private let fileType = ["app"]

    private var applications = [Application]() {
        didSet {
            if let tableView = self.tableView {
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
            }
        }
    }

    public var preferences: Preferences? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.registerForDraggedTypes([dragDropType])

        let sortValid = NSSortDescriptor(key: "isInvalid", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        tableView.tableColumns[0].sortDescriptorPrototype = sortValid

        let sortName = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        tableView.tableColumns[1].sortDescriptorPrototype = sortName

        let sortShow = NSSortDescriptor(key: "showInApplicationsWindow", ascending: false, selector: #selector(NSNumber.compare(_:)))
        tableView.tableColumns[3].sortDescriptorPrototype = sortShow

        if let currentPreferences = self.preferences {
            self.applications = currentPreferences.getApplications()
        }
    }

    private func updateApplications() {
        if let currentPreferences = PreferenceLoader.currentPreferences {
            currentPreferences.setApplications(self.applications)

            PreferenceLoader.save(currentPreferences, notify: false)
            if let preferencesViewController = self.preferencesViewController {
                preferencesViewController.applicationsCountLabel.stringValue = "\(self.applications.count) application(s)"
            }
            NotificationCenter.default.post(name: ItemRepository.updatingApplications, object: self.applications)
        }
    }

}

extension PreferencesApplicationsViewController: NSTableViewDataSource, NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let ApplicationNameCell = "ApplicationNameCell"
        static let ApplicationStatusCell = "ApplicationStatusCell"
        static let ApplicationPathCell = "ApplicationPathCell"
        static let ApplicationEnableCell = "ApplicationEnableCell"
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

        if dropOperation == .above {
            return .move
        }
        return .generic
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let oldApplications = applications
        applications.sort(sortDescriptors: tableView.sortDescriptors)

        if applications != oldApplications {
            updateApplications()
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let board = info.draggingPasteboard.propertyList(forType: fileNameType) as? NSArray {
            if let path = board[0] as? String {
                let suffix = URL(fileURLWithPath: path).pathExtension
                for ext in self.fileType {
                    if ext.lowercased() == suffix {
                        return addAppAt(path)
                    }
                }
            }
        } else {
            var oldIndexes = [Int]()
            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
                if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                    oldIndexes.append(index)
                }
            }

            var oldIndexOffset = 0
            var newIndexOffset = 0

            // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
            // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
            tableView.beginUpdates()
            for oldIndex in oldIndexes {
                if oldIndex < row {
                    tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                    applications.move(from: oldIndex + oldIndexOffset, to: row - 1)
                    oldIndexOffset -= 1
                } else {
                    tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                    applications.move(from: oldIndex, to: row + newIndexOffset)
                    newIndexOffset += 1
                }
            }


            tableView.endUpdates()
            updateApplications()

            return true
        }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var image: NSImage? = nil
        var cellIdentifier: String = ""

        let application = applications[row]

        if tableColumn == tableView.tableColumns[0] {
            image = !application.isInvalid ? NSImage(named: "NSStatusAvailable") : NSImage(named: "NSStatusUnavailable")
            cellIdentifier = CellIdentifiers.ApplicationStatusCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = application.name
            cellIdentifier = CellIdentifiers.ApplicationNameCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = application.path
            cellIdentifier = CellIdentifiers.ApplicationPathCell
        } else if tableColumn == tableView.tableColumns[3] {
            cellIdentifier = CellIdentifiers.ApplicationEnableCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            if let _image = image {
                cell.imageView?.image = _image
            }

            if cellIdentifier == CellIdentifiers.ApplicationEnableCell {
                if let checkBox = (cell.subviews.first { type(of: $0) == NSButton.self }) as? NSButton {
                    checkBox.state = (application.showInApplicationsWindow ? .on : .off)
                }
            }
            return cell
        }

        return nil
    }

    @IBAction func toggleShownStatus(_ sender: NSButton) {
        let row = tableView.row(for: sender)

        if applications.indices.contains(row) {
            applications[row].showInApplicationsWindow = (sender.state == .on)
            updateApplications()
        }

    }

    @IBAction func openContainingFolderButtonClicked(_ sender: NSButton) {
        let selectedIndex = tableView.selectedRow
        if applications.indices.contains(selectedIndex) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: applications[selectedIndex].path)])
        }
    }

    @IBAction func appControlButtonClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            DDLogError("This function is not implemented yet")
        } else {
            removeAppSelected()
        }
    }

    private func appIsValidAt(_ appPath: String?) -> Bool {
        if let validPath = appPath {
            let fileManager = FileManager.default
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: validPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    return true
                }
            }
        }
        return false
    }

    private func addAppAt(_ appPath: String) -> Bool {
        let appName = String(appPath.split(separator: "/").last!).replacingOccurrences(of: ".app", with: "")
        if (!applications.contains { $0.name == appName }) {
            let newApplication = Application(name: appName, path: appPath)
            newApplication.showInApplicationsWindow = true

            applications.append(newApplication)
            tableView.reloadData()
            updateApplications()
            return true
        }

        return false
    }

    private func removeAppSelected() {
        tableView.selectedRowIndexes.forEach {
            if applications.indices.contains($0) {
                let existingApplication = applications[$0]
                applications.removeAll { $0 == existingApplication }
                updateApplications()
            }
        }
    }



    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return applications.count
    }
}
