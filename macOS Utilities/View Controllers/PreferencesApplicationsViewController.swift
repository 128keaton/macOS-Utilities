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

class PreferencesApplicationsViewController: NSViewController, NSMenuItemValidation {
    @IBOutlet weak var tableView: NSTableView!

    public var preferencesViewController: PreferencesViewController? = nil

    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "public.data")
    private var fileNameType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")

    private let fileTypes = ["app", "plist"]

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

        addSortDescriptors()
        addContextMenu()
    }

    func addSortDescriptors() {
        let sortValid = NSSortDescriptor(key: "isValid", ascending: false, selector: #selector(NSNumber.compare(_:)))
        tableView.tableColumns[0].sortDescriptorPrototype = sortValid

        let sortName = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        tableView.tableColumns[1].sortDescriptorPrototype = sortName

        let sortShow = NSSortDescriptor(key: "showInApplicationsWindow", ascending: false, selector: #selector(NSNumber.compare(_:)))
        tableView.tableColumns[3].sortDescriptorPrototype = sortShow

        if let currentPreferences = self.preferences,
            let applications = currentPreferences.getApplications() {
            self.applications = applications
        }
    }

    func addContextMenu() {
        let contextMenu = NSMenu()

        let openInFinderItem = NSMenuItem(title: "Open in Finder..", action: #selector(PreferencesApplicationsViewController.tableViewShowItemInFinderClicked(_:)), keyEquivalent: "")
        openInFinderItem.target = self

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(PreferencesApplicationsViewController.tableViewDeleteItemClicked(_:)), keyEquivalent: "")
        deleteItem.target = self


        contextMenu.addItem(openInFinderItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(deleteItem)

        tableView.menu = contextMenu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard tableView.clickedRow >= 0 else { return false }

        if menuItem.title == "Delete" {
            return true
        } else {
            if applications.indices.contains(tableView.clickedRow) {
                return applications[tableView.clickedRow].isValid
            }
        }
        return false
    }

    @objc func sortByValid(_ a: AnyObject) {
        print(a)
    }

    private func updateApplications() {
        if let currentPreferences = PreferenceLoader.currentPreferences {
            currentPreferences.setApplications(self.applications)

            PreferenceLoader.save(currentPreferences, notify: false)
            if let preferencesViewController = self.preferencesViewController {
                preferencesViewController.applicationsCountLabel.stringValue = "\(self.applications.count) application(s)"
            }

            ItemRepository.shared.addToRepository(newItems: self.applications, merge: true)
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
            applications = applications.filter { $0.applicationPath != "" }
            updateApplications()
            tableView.reloadData()
        }
    }

    @objc private func tableViewShowItemInFinderClicked(_ sender: NSMenuItem) {
        guard tableView.clickedRow >= 0 else { return }
        if applications.indices.contains(tableView.clickedRow) {
            let application = applications[tableView.clickedRow]
            if application.isValid {
                NSWorkspace.shared.activateFileViewerSelecting([application.applicationPath.fileURL])
            }
        }
    }

    @objc private func tableViewDeleteItemClicked(_ sender: NSMenuItem) {
        guard tableView.clickedRow >= 0 else { return }
        applications.remove(at: tableView.clickedRow)
        updateApplications()
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let filePaths = info.draggingPasteboard.propertyList(forType: fileNameType) as? [String] {
            for path in filePaths {
                let suffix = URL(fileURLWithPath: path).pathExtension
                if fileTypes.contains(suffix.lowercased()) {
                    if suffix.lowercased() == "app" {
                        let _ = addAppAt(path)
                    } else if suffix.lowercased() == "plist" {
                        let _ = updateFromLegacyPlist(path)
                    }
                }
            }
            return true
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
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var image: NSImage? = nil
        var cellIdentifier: String = ""

        let application = applications[row]

        if tableColumn == tableView.tableColumns[0] {
            image = application.isValid ? NSImage(named: "NSStatusAvailable") : NSImage(named: "NSStatusUnavailable")
            cellIdentifier = CellIdentifiers.ApplicationStatusCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = application.name
            cellIdentifier = CellIdentifiers.ApplicationNameCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = application.applicationPath
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

    @IBAction func appPathUpdated(_ sender: NSTextField) {
        let row = tableView.row(for: sender)

        if applications.indices.contains(row) {
            if sender.stringValue != "" || applications[row].name != "" {
                applications[row].updatePath(sender.stringValue)
            } else {
                applications.remove(at: row)
            }

            updateApplications()
            tableView.reloadData()
        }
    }

    @IBAction func appNameUpdated(_ sender: NSTextField) {
        let row = tableView.row(for: sender)

        if applications.indices.contains(row) {
            if sender.stringValue != "" || applications[row].applicationPath != "" {
                applications[row].updateName(sender.stringValue)
            } else {
                applications.remove(at: row)
            }

            updateApplications()
            tableView.reloadData()
        }
    }

    @IBAction func openContainingFolderButtonClicked(_ sender: NSButton) {
        let foldersToOpen = tableView.selectedRowIndexes.map { index -> Application? in
            if applications.indices.contains(index) { return applications[index] } else { return nil }
        }.filter { $0 != nil }.map { URL(fileURLWithPath: $0!.applicationPath) }

        NSWorkspace.shared.activateFileViewerSelecting(foldersToOpen)
    }

    @IBAction func appControlButtonClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            applications.insert(Application(name: "", path: ""), at: 0)

            tableView.beginUpdates()
            tableView.insertRows(at: IndexSet(integer: 0), withAnimation: .effectFade)
            tableView.endUpdates()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.editRowAt(0)
            }
        } else {
            removeAppSelected()
        }
    }

    private func editRowAt(_ position: Int) {
        if let cellAt = tableView.view(atColumn: 1, row: position, makeIfNecessary: false) {
            if let textField = ( cellAt.subviews.first { type(of: $0) == NSTextField.self }) {
                textField.becomeFirstResponder()
            }
        }
    }

    private func updateFromLegacyPlist(_ plistPath: String) -> Bool {
        var serializerFormat = PropertyListSerialization.PropertyListFormat.xml
        var applicationData = [String: AnyObject]()

        if let plistXML = FileManager.default.contents(atPath: plistPath) {
            do {
                applicationData = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &serializerFormat) as! [String: AnyObject]
                // Legacy, v1.0 format
                if let unmappedApplications = applicationData["Applications"] as? [String: [String: String]] {
                    var applicationNames = [String]()
                    var addStatus = [Bool]()

                    unmappedApplications.forEach { $1.forEach {
                        applicationNames.append($0)
                        addStatus.append(addAppAt($1))
                    } }


                    let errorMessage = addStatus.enumerated().map { (arg) -> String in
                        let (index, status) = arg
                        if !status { return "Could not add application \(applicationNames[index]): application already present in list." } else { return "" }
                    }.joined(separator: "\n")

                    if errorMessage != "" {
                        DDLogError(errorMessage)
                    }

                    return true
                }
            } catch {
                DDLogError("Error reading legacy plist: \(error), format: \(serializerFormat)")
            }
        }
        return false
    }

    private func addAppAt(_ appPath: String) -> Bool {
        let appName = String(appPath.split(separator: "/").last!).replacingOccurrences(of: ".app", with: "")
        if (!applications.contains { $0.name == appName }) {
            let newApplication = Application(name: appName, path: appPath)

            applications.append(newApplication)
            tableView.reloadData()
            updateApplications()
            return true
        }

        return false
    }

    private func removeAppSelected() {
        let applicationsToRemove = tableView.selectedRowIndexes.map { index -> Application? in
            if applications.indices.contains(index) { return applications[index] } else { return nil }
        }.filter { $0 != nil }

        applications = applications.filter { !applicationsToRemove.contains($0) }

        updateApplications()
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return applications.count
    }

}
