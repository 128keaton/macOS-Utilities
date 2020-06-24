//
//  IPAddressAlert.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class IPAddressChooserDialog: NSViewController {
    @IBOutlet weak var chooseButton: NSButton!
    @IBOutlet weak var tableView: NSTableView!

    private var ipAddresses: [String]
    private var ipAddressSelected: String? = nil
    private var completionHandler: ((String) -> Void)? = nil

    public var fromViewController: NSViewController? = nil

    private static let aNibName = "IPAddressChooserDialog"

    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        self.ipAddresses = Host.current().addresses.filter { $0.contains("::") == false }
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        self.ipAddresses = Host.current().addresses.filter { $0.contains("::") == false }
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        self.title = ""
        self.chooseButton.isEnabled = false
        self.tableView.reloadData()
    }

    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        fromViewController?.dismiss(self)
    }

    @IBAction func chooseButtonClicked(_ sender: NSButton) {
        if let completionHandler = self.completionHandler,
            let ipAddressSelected = self.ipAddressSelected {
            completionHandler(ipAddressSelected)
            fromViewController?.dismiss(self)
        }
    }

    override func viewWillAppear() {
        view.window!.styleMask.remove(.resizable)
        view.window!.styleMask.remove(.closable)
        view.window!.styleMask.remove(.miniaturizable)

        super.viewWillAppear()
    }

    static func show(_ from: NSViewController, completionHandler handler: ((String) -> Void)? = nil) {
        let instance = IPAddressChooserDialog.init(nibName: aNibName, bundle: nil)
        from.presentAsModalWindow(instance)

        instance.fromViewController = from
        if let completionHandler = handler {
            instance.completionHandler = completionHandler
        }
    }
}

extension IPAddressChooserDialog: NSTableViewDelegate, NSTableViewDataSource, NSTableViewDelegateDeselectListener {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.ipAddresses.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableColumn == tableView.tableColumns.first!{
            return self.ipAddresses[row]
        }
        return "(this machine)"
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        self.ipAddressSelected = ipAddresses[row]
        self.chooseButton?.isEnabled = true

        return true
    }

    func tableView(_ tableView: NSTableView, didDeselectAllRows: Bool) {
        self.chooseButton?.isEnabled = !didDeselectAllRows
    }
}
