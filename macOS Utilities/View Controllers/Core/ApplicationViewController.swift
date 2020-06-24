//
//  ViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import AppFolder
import CocoaLumberjack

class ApplicationViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var installMacOSButton: NSButton?
    @IBOutlet weak var copyrightLabel: NSTextField!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var errorButton: NSButton?

    private var preferenceLoader: PreferenceLoader? = nil
    private let itemRepository = ItemRepository.shared
    private var peerCommunicationService: PeerCommunicationService? = nil
    private var appRows: [AppCellView] = []
    private let reloadQueue = DispatchQueue(label: "thread-safe-obj", attributes: .concurrent)

    static let reloadApplications = Notification.Name("ReloadApplications")

    override func viewDidLoad() {
        super.viewDidLoad()

        if let appVersion = AppDelegate.getApplicationVersion() {
            self.versionLabel.stringValue = "Version \(appVersion)"
        }

        self.errorButton?.blink(toValue: 0.3)
        self.registerForNotifications()
        self.showIPAddress()
        self.tableView.action = #selector(tableViewClicked)
    }

    override func viewDidAppear() {
        if self.peerCommunicationService == nil {
            self.peerCommunicationService = PeerCommunicationService.instance
        }

        self.peerCommunicationService?.updateStatus("Idle")
    }

    private func checkForExceptions() {
        if !ExceptionHandler.hasExceptions {
            return
        }

        showInfoAlert(title: "Hello There", message: "Looks like macOS Utilities crashed the last time it was used. Would you like to log this issue?") { (shouldLog) in
            if (shouldLog) {
                ExceptionHandler.exceptions.forEach({ (exceptionItem) in
                    var message = "Exception at \(exceptionItem.exceptionDate): \n"
                    message += "Name: \(exceptionItem.exception.name).\n"
                    message += "\(exceptionItem.exception)"

                    DDLogError(message)
                })

                ExceptionHandler.clearExceptions()
            }
        }
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.addApplication(_:)), name: GlobalNotifications.newApplication, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.reloadAllApplications), name: GlobalNotifications.newApplications, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.reloadAllApplications), name: GlobalNotifications.reloadApplications, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.addInstaller(_:)), name: GlobalNotifications.newInstaller, object: nil)
    }

    private func showIPAddress() {
        guard let networkAddress = (NetworkUtils.getAllAddresses().first { (address) -> Bool in
                let validIP = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
                return (address.range(of: validIP, options: .regularExpression) != nil)
            }) else {
            return
        }

        self.copyrightLabel.stringValue = "IP: \(networkAddress) - Remote Log: \(networkAddress):8080"
    }

    @objc private func addInstaller(_ aNotification: Notification? = nil) {
        guard let notification = aNotification else { return }
        if (notification.object as? Installer) != nil {
            DispatchQueue.main.async {
                self.installMacOSButton?.isEnabled = true
                self.addTouchBarInstallButton()
                self.errorButton?.blinkOff()

                NSAnimationContext.runAnimationGroup { (context) in
                    context.duration = 0.5
                    self.errorButton?.alphaValue = 0.0
                    self.errorButton?.isEnabled = false
                }
            }
        }
    }

    @objc private func addApplication(_ aNotification: Notification? = nil) {
        guard let notification = aNotification else { return }
        if (notification.object as? Application) != nil {
            self.hideAllApplications()
            self.tableView.reloadData()
            self.showAllApplications()
        }
    }

    @objc private func reloadAllApplications() {
        self.hideAllApplications()

        DispatchQueue.main.async {
            KBLogDebug("Reloading all applications")

            self.tableView.reloadData()

            DispatchQueue.main.async {
                self.showAllApplications()
            }
        }
    }

    private func hideAllApplications() {
        self.appRows.forEach { $0.hide() }
    }

    private func showAllApplications() {
        self.appRows.forEach { $0.show() }
    }

    @IBAction func installMacOSButtonClicked(_ sender: NSButton) {
        self.startMacOSInstall()
    }

    @objc private func startMacOSInstall() {
        PageController.shared.showPageController()
    }

    @objc private func openPreferences() {
        if let preferencesWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "preferencesWindowController") as? NSWindowController {
            preferencesWindow.showWindow(self)
        }
    }

    @objc private func getInfo() {
        if let getInfoWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "getInfoWindowController") as? NSWindowController {
            getInfoWindow.showWindow(self)
        }
    }

    @objc private func tableViewClicked() {
        if self.itemRepository.allowedApplications.indices.contains(self.tableView.selectedRow) {
            let selectedApp = self.itemRepository.allowedApplications[self.tableView.selectedRow]
            if let selectedRow = self.tableView.rowView(atRow: self.tableView.selectedRow, makeIfNecessary: false) {
                selectedRow.blink(toValue: 0.5, once: true)
            }


            self.itemRepository.openApplication(selectedApp)
            PeerCommunicationService.instance.updateStatus("Running \(selectedApp.name)")

            self.tableView.deselectRow(self.tableView.selectedRow)
        }
    }

    func removeTouchBarInstallButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.getInfo, .openPreferences]
        }
    }

    func addTouchBarInstallButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.installMacOS, .getInfo, .openPreferences]
        }
    }
}

extension ApplicationViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return itemRepository.allowedApplications.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let appCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("AppCell"), owner: nil) as? AppCellView {
            appCell.application = self.itemRepository.allowedApplications[row]

            self.appRows.append(appCell)
            return appCell
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let app = self.itemRepository.allowedApplications[row]

        if !app.isValid {
            return false
        }

        return true
    }
}

extension NSTouchBarItem.Identifier {
    static let installMacOS = NSTouchBarItem.Identifier("com.keaton.utilities.installMacOS")
    static let getInfo = NSTouchBarItem.Identifier("com.keaton.utilities.getInfo")
    static let closeCurrentWindow = NSTouchBarItem.Identifier("com.keaton.utilities.closeCurrentWindow")
    static let backPageController = NSTouchBarItem.Identifier("com.keaton.utilities.back")
    static let nextPageController = NSTouchBarItem.Identifier("com.keaton.utilities.next")
    static let openPreferences = NSTouchBarItem.Identifier("com.keaton.utilities.openPreferences")
}

extension ApplicationViewController: NSTouchBarDelegate {

    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.getInfo, .openPreferences]

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        case NSTouchBarItem.Identifier.installMacOS:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSInstallIcon")!, target: self, action: #selector(startMacOSInstall))
            return item

        case NSTouchBarItem.Identifier.getInfo:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGetInfoTemplate")!, target: self, action: #selector(getInfo))
            return item

        case NSTouchBarItem.Identifier.openPreferences:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSActionTemplate")!, target: self, action: #selector(openPreferences))
            return item

        default: return nil
        }
    }
}
