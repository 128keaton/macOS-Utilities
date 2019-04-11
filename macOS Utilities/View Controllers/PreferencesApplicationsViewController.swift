//
//  PreferencesApplicationsViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/11/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class PreferencesApplicationsViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!

    public var applications = [String: [String: String]]() {
        didSet {
            if let tableView = self.tableView {
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
            }
        }
    }

    public var preferencesViewController: PreferencesViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        if applications.count > 0 {
            print(applications.keys)
            tableView.reloadData()
        }
    }
}

extension PreferencesApplicationsViewController: NSTableViewDataSource, NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let ApplicationNameCell = "ApplicationNameCell"
        static let ApplicationSectionCell = "ApplicationSectionCell"
        static let ApplicationPathCell = "ApplicationPathCell"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        let key = Array(applications.keys)[row]
        let application = applications[key]

        if tableColumn == tableView.tableColumns[0] {
            text = key
            cellIdentifier = CellIdentifiers.ApplicationNameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = application!["Section"]!
            cellIdentifier = CellIdentifiers.ApplicationSectionCell
        } else {
            text = application!["Path"]!
            cellIdentifier = CellIdentifiers.ApplicationPathCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }

        return nil
    }

    @IBAction func openContainingFolderButtonClicked(_ sender: NSButton) {
        let selectedIndex = tableView.selectedRow
        if Array(applications.keys).indices.contains(selectedIndex) {
            let key = Array(applications.keys)[selectedIndex]
            if let application = applications[key] {
                guard let applicationPath = application["Path"] else { return }
                NSWorkspace.shared.selectFile(applicationPath, inFileViewerRootedAtPath: applicationPath.replacingOccurrences(of: key, with: ""))
            }
        }
    }

    @IBAction func appControlButtonClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            addApp()
        } else {
            removeAppSelected()
        }
    }

    private func addApp() {
        let dialog = NSOpenPanel();

        dialog.title = "Choose an application";
        dialog.showsResizeIndicator = false;
        dialog.canChooseDirectories = false;
        dialog.canChooseFiles = true;
        dialog.allowedFileTypes = ["app"];

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file

            if (result != nil) {
                let path = result!.path
                var newApplication = [String: String]()
                
                newApplication["Path"] = path
                newApplication["Section"] = ""
                
                applications[result!.lastPathComponent] = newApplication
            }
        } else {
            return
        }
    }

    private func removeAppSelected() {
        let selectedIndex = tableView.selectedRow
        if Array(applications.keys).indices.contains(selectedIndex) {
            let key = Array(applications.keys)[selectedIndex]
            applications.removeValue(forKey: key)
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return applications.keys.count
    }

    override func viewWillDisappear() {
        (NSApplication.shared.delegate as! AppDelegate).preferenceLoader.updateApplications(applications, shouldSave: false)
        if let preferencesViewController = self.preferencesViewController {
            preferencesViewController.readPreferences()
        }
    }
}
