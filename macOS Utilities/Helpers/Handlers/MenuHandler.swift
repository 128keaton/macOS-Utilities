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

    public var fileMenu: NSMenu?
    public var preferencesMenuItem: NSMenuItem?

    public var installers = [Installer]()
    public var helpEmailAddress: String? = nil
    public var pageControllerDelegate: NSPageController? = nil

    public static let shared = MenuHandler()

    private let sharedOverlayLogger = XLOverlayLog.shared

    private override init() {
        super.init()
        
        registerForNotifications()
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(MenuHandler.addInstallerToMenu(_:)), name: GlobalNotifications.newInstaller, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenuHandler.addUtilityToMenu(_:)), name: GlobalNotifications.newUtility, object: nil)
    }

    // MARK: Menu Builders
    func buildHelpMenu() {
        if self.helpMenu != nil {
            #if DEBUG
                ItemRepository.shared.createFakeInstallers()
            #endif

            if helpEmailAddress == nil {
                helpMenu!.items.forEach {
                    if $0.title == "Send Log" {
                         helpMenu!.removeItem($0)
                    }
                }
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
    @IBAction func exportCurrentConfiguration(_ sender: NSMenuItem) {
        if PreferenceLoader.savePreferencesToDownloads(PreferenceLoader.currentPreferences!, fileName: "exported-\(String.random(5, numericOnly: true))") {
            DDLogInfo("Exported configuration successfully")
            return
        }
        DDLogError("Could not export current configuration")
    }

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
                        let didLoad = PreferenceLoader.loadPreferences(propertyListURL, updatingRunning: true)
                        if didLoad {
                            DDLogInfo("Loaded preferences from: \(propertyListURL)")
                        } else {
                            DDLogError("Failed to load preferences from: \(propertyListURL)")
                        }
                    }
                }
            }
        }
    }

    // MARK: Debug menu functions
    @IBAction func reloadPreferences(_ sender: NSMenuItem) {
        ItemRepository.shared.reloadAllItems()
    }

    @IBAction func reloadApplications(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: ApplicationViewController.reloadApplications, object: nil)
    }

    @IBAction func ejectAll(_ sender: NSMenuItem) {
        DiskUtility.ejectAll() { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
        }
    }

    @IBAction func forceReloadAllDisks(_ sender: NSMenuItem) {
        DiskUtility.ejectAll() { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
            if let preferences = PreferenceLoader.currentPreferences,
                let installerServerPreferences = preferences.installerServerPreferences {
                HardDriveImageUtility.mountDiskImagesAt(installerServerPreferences.mountPath)
            }
        }
    }

    @IBAction func triggerException(_ sender: NSMenuItem) {
        fatalError("Test Fatal Error")
    }

    @IBAction func forceFusionDrive(_ sender: NSMenuItem) {
        if DiskUtility.forceFusionDrive {
            DDLogVerbose("Forcing scanning for Fusion Drive is now on")
            sender.state = .off
        } else {
            DDLogVerbose("Forcing scanning for Fusion Drive is now off")
            sender.state = .on
        }

        DiskUtility.forceFusionDrive = !DiskUtility.forceFusionDrive
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
    @objc func openCoverageLink() {
        // Unfortunately, this is rate limited :/
        if let serial = NSApplication.shared.getSerialNumber() {
            NSWorkspace().open(URL(string: "https://checkcoverage.apple.com/us/en/?sn=\(serial)")!)
        }
    }

    @objc func startOSInstall(_ sender: NSMenuItem) {
        installers = ItemRepository.shared.installers
        let versionName = sender.title.replacingOccurrences(of: "Install ", with: "")

        DDLogVerbose("Attempting macOS Install: \(versionName)")

        if let indexOfSender = infoMenu?.items.firstIndex(of: sender),
            installers.indices.contains(indexOfSender) == true,
            let selectedInstaller = (installers.first { $0.version == Version(versionName: versionName) }) {

            ItemRepository.shared.setSelectedInstaller(selectedInstaller)
            PageController.shared.showPageController(initialPage: 1)
        } else {
            DDLogError("Could not start macOS Install: Unable to find installer for \(versionName)")
        }
    }


    // MARK: Help menu functions
    @objc @IBAction func sendLog(_ sender: NSMenuItem) {
        let logFilePaths = (DDLog.allLoggers.first { $0 is DDFileLogger } as! DDFileLogger).logFileManager.sortedLogFilePaths.map { URL(fileURLWithPath: $0) }
        if NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: "com.apple.mail") != nil {
            let emailService = NSSharingService(named: .composeEmail)
            let htmlContent = "<h2>Please type your issue here:</h2><br><p>Replace Me</p>".data(using: .utf8)

            var items: [Any] = [NSAttributedString(html: htmlContent!, options: [:], documentAttributes: nil)!]
            let emailSubject = Host.current().localizedName != nil ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__)") : String("\(Sysctl.model)")

            logFilePaths.forEach { items.append($0) }

            emailService?.subject = emailSubject
            emailService?.recipients = [helpEmailAddress!]
            emailService?.perform(withItems: items)
        } else if logFilePaths.count > 0 {
            DDLogVerbose("No Mail application, lets go to the folder then.")
            NSWorkspace.shared.activateFileViewerSelecting(logFilePaths)
        }
    }

    @IBAction func showLog(_ sender: NSMenuItem) {
        if let logFilePath = (DDLog.allLoggers.first { $0 is DDFileLogger } as! DDFileLogger).logFileManager.sortedLogFilePaths.first {
            NSWorkspace.shared.open(logFilePath.fileURL)
        }
    }

    @IBAction func toggleLog(_ sender: NSMenuItem) {
        if !sharedOverlayLogger.isHidden {
            sharedOverlayLogger.hide()
            sender.title = "Show Log Overlay"
        } else {
            sharedOverlayLogger.show()
            sender.title = "Hide Log Overlay"
        }
    }

    // MARK: Data Functions
    @objc private func addUtilityToMenu(_ notification: Notification? = nil) {
        if let validNotification = notification {
            if let utility = validNotification.object as? Utility {
                removeUtilityPlaceholder()
                let newItem = NSMenuItem(title: utility.name, action: #selector(MenuHandler.openApp(_:)), keyEquivalent: "")
                newItem.target = self
                utilitiesMenu?.addItem(newItem)
            }
        }
    }

    private func removeUtilityPlaceholder() {
        if (utilitiesMenu?.items.first { $0.isEnabled == false }) != nil {
            utilitiesMenu?.items.forEach {
                if $0.isEnabled == false {
                    utilitiesMenu?.removeItem($0)
                }
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
                    installers.append(installer)
                    let installerItem = NSMenuItem(title: "Install \(installer.version.name)", action: #selector(MenuHandler.startOSInstall(_:)), keyEquivalent: "")
                    installerItem.target = self
                    installerItem.image = installer.canInstall ? NSImage(named: "NSStatusAvailable") : NSImage(named: "NSStatusUnavailable")
                    infoMenu.insertItem(installerItem, at: 0)
                }
            }
        }
    }

    @objc func openApp(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: GlobalNotifications.openApplication, object: sender.title)
    }
}

