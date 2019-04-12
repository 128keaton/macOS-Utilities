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

        if #available(OSX 10.13, *) {
            tableView.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL])
        } else {
            tableView.registerForDraggedTypes([NSPasteboard.PasteboardType.filePromise])
        }

        if let currentPreferences = self.preferences {
            self.applications = currentPreferences.getApplications()
        }
    }

    private func updateApplications() {
        if let currentPreferences = PreferenceLoader.currentPreferences {
            currentPreferences.setApplications(self.applications)
            PreferenceLoader.save(currentPreferences, notify: false)
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

    func tableView(_ tableView: NSTableView, namesOfPromisedFilesDroppedAtDestination dropDestination: URL, forDraggedRowsWith indexSet: IndexSet) -> [String] {
        print(dropDestination)

        return ["Hest"]
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

        if dropOperation == .above {
            return .move
        }
        return .generic
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let board = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = board[0] as? String
            else { return false }

        let suffix = URL(fileURLWithPath: path).pathExtension
        for ext in self.fileType {
            if ext.lowercased() == suffix {
                addAppAt(path)
                return true
            }
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
                print(cell.subviews)
            }

            return cell
        }

        return nil
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

    private func addAppAt(_ appPath: String) {
        let appName = String(appPath.split(separator: "/").last!).replacingOccurrences(of: ".app", with: "")
        if (!applications.contains { $0.name == appName }) {
            let newApplication = Application(name: appName, path: appPath)
            newApplication.showInApplicationsWindow = true

            applications.append(newApplication)
            tableView.reloadData()
            updateApplications()
        }
    }

    private func removeAppSelected() {
        let selectedIndex = tableView.selectedRow
        if applications.indices.contains(selectedIndex) {
            let existingApplication = applications[selectedIndex]
            applications.removeAll { $0 == existingApplication }
            updateApplications()
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return applications.count
    }
}
