//
//  MenuHandler.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/16/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Cocoa
import CocoaLumberjack

class MenuHandler: NSObject {
    public var utilitiesMenu: NSMenu?
    public var infoMenu: NSMenu? {
        didSet {
            self.buildInfoMenu()
        }
    }
    public var helpMenu: NSMenu? {
        didSet {
            self.buildHelpMenu()
        }
    }
    
    public var installers = [Installer]()
    public var helpEmailAddress: String? = nil
    public var pageControllerDelegate: NSPageController? = nil

    public static let shared = MenuHandler()

    private override init() {
        super.init()
        registerForNotifications()
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(MenuHandler.addInstallerToMenu(_:)), name: ItemRepository.newInstaller, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenuHandler.addUtilityToMenu(_:)), name: ItemRepository.newUtility, object: nil)
    }

    // MARK: Menu Builders
    func buildHelpMenu() {
        if self.helpMenu != nil {
            if helpEmailAddress == nil {
                helpMenu!.items.removeAll { $0.title == "Send Log" }
                DDLogInfo("Disabling 'Send Log' menu item. helpEmailAddress is nil")
            } else {
                if (helpMenu?.items.filter { $0.title == "Send Log" })!.count == 0 {
                    infoMenu?.addItem(withTitle: "Send Log", action: #selector(MenuHandler.sendLog(_:)), keyEquivalent: "")
                }
            }
        }
    }

    func buildInfoMenu() {
        if(infoMenu?.items.count ?? 0 > 0) {
            infoMenu?.addItem(NSMenuItem.separator())
        }

        infoMenu?.addItem(withTitle: Sysctl.model, action: nil, keyEquivalent: "")
        if let serial = NSApplication.shared.getSerialNumber() {
            infoMenu?.addItem(withTitle: serial, action: nil, keyEquivalent: "")
            infoMenu?.addItem(NSMenuItem.separator())

            let checkWarrantyItem = NSMenuItem(title: "Check Warranty", action: #selector(MenuHandler.openCoverageLink), keyEquivalent: "")
            checkWarrantyItem.target = self
            infoMenu?.addItem(checkWarrantyItem)
        }
    }

    // MARK: File menu functions
    @IBAction func loadConfigurationFile(_ sender: NSMenuItem) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["plist", "utilconf"]
        openPanel.allowsMultipleSelection = false
        openPanel.allowsOtherFileTypes = false
        openPanel.showsHiddenFiles = true
        openPanel.canChooseDirectories = false

        openPanel.title = "Browse for existing configuration property list file"
        openPanel.message = "A legacy configuration file will be automatically updated if selected"

        openPanel.begin { (response) in
            if response == .OK {
                if let propertyListURL = openPanel.url {
                    DispatchQueue.main.async {
                        KBTextFieldDialog.show(NSApp.keyWindow!.contentViewController!, doneButtonText: "Done", textFieldPlaceholder: "New Configuration Name", dialogTitle: "Load configuration from URL", completionHandler: { (newConfigurationName) in
                            let newConfiguration = RemoteConfigurationPreferences(filePath: propertyListURL, name: newConfigurationName)
                            PreferenceLoader.sharedInstance?.addRemoteConfiguration(newConfiguration)
                        })
                    }
                }
            }
        }
    }


    // MARK: Debug menu functions
    @IBAction func reloadPreferences(_ sender: NSMenuItem) {
        ItemRepository.shared.reloadAllItems()
    }

    @IBAction func ejectAll(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll() { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
        }
    }

    @IBAction func forceReloadAllDisks(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll() { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
            if let preferences = PreferenceLoader.currentPreferences,
                let installerServerPreferences = preferences.installerServerPreferences {
                DiskUtility.shared.mountDiskImagesAt(installerServerPreferences.mountPath)
            }
        }
    }

    @IBAction func createFakeInstallerNonInstallable(_ sender: NSMenuItem) {
        ItemRepository.shared.addFakeInstaller()
    }

    @IBAction func createFakeInstaller(_ sender: NSMenuItem) {
        ItemRepository.shared.addFakeInstaller(canInstallOnMachine: true)
    }

    @IBAction func testURLScheme(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "open-utilities://test")!)
    }


    // MARK: Info menu functions
    // Unfortunately, this is rate limited :/
    @objc func openCoverageLink() {
        if let serial = NSApplication.shared.getSerialNumber() {
            NSWorkspace().open(URL(string: "https://checkcoverage.apple.com/us/en/?sn=\(serial)")!)
        }
    }

    @objc func startOSInstall(_ sender: NSMenuItem) {
        if let indexOfSender = infoMenu?.items.firstIndex(of: sender) {
            guard installers.indices.contains(indexOfSender) == true
                else {
                    return
            }

            let installerVersion = String(sender.title.split(separator: " ")[1])

            if let selectedInstaller = (installers.first { $0.versionNumber == Double(installerVersion)! }) {
                ItemRepository.shared.setSelectedInstaller(selectedInstaller)
                PageController.shared.showPageController(initialPage: 1)
            }
        }
    }


    // MARK: Help menu functions
    @objc @IBAction func sendLog(_ sender: NSMenuItem) {
        let emailService = NSSharingService(named: .composeEmail)
        let logFilePaths = (DDLog.allLoggers.first { $0 is DDFileLogger } as! DDFileLogger).logFileManager.sortedLogFilePaths.map { URL(fileURLWithPath: $0) }
        let htmlContent = "<h2>Please type your issue here:</h2><br><p>Replace Me</p>".data(using: .utf8)

        var items: [Any] = [NSAttributedString(html: htmlContent!, options: [:], documentAttributes: nil)!]
        let emailSubject = Host.current().localizedName != nil ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__\(getSystemUUID() ?? ""))") : String("\(Sysctl.model)__(\(getSystemUUID() ?? ""))")

        logFilePaths.forEach { items.append($0) }

        emailService?.subject = emailSubject
        emailService?.recipients = [helpEmailAddress!]
        emailService?.perform(withItems: items)
    }

    // MARK: Data Functions
    @objc private func addUtilityToMenu(_ notification: Notification? = nil) {
        if let validNotification = notification {
            if let utility = validNotification.object as? Application {
                let newItem = NSMenuItem(title: utility.name, action: #selector(MenuHandler.openApp(_:)), keyEquivalent: "")
                newItem.target = self
                utilitiesMenu?.addItem(newItem)
            }
        }
    }

    @objc private func addInstallerToMenu(_ notification: Notification? = nil) {
        if let infoMenu = self.infoMenu {
            if (infoMenu.items.filter { $0 == NSMenuItem.separator() }).count == 1 {
                infoMenu.insertItem(NSMenuItem.separator(), at: 1)
            }

            if let validNotification = notification {
                if let installer = validNotification.object as? Installer {
                    let installerItem = NSMenuItem(title: "Install \(installer.versionName)", action: #selector(MenuHandler.startOSInstall(_:)), keyEquivalent: "")
                    installerItem.target = self
                    installerItem.image = installer.canInstall ? NSImage(named: "NSStatusAvailable") : NSImage(named: "NSStatusUnavailable")
                    infoMenu.insertItem(installerItem, at: 0)
                }
            }
        }
    }

    @objc func openApp(_ sender: NSMenuItem) {
        ApplicationUtility.shared.open(sender.title)
    }
}

