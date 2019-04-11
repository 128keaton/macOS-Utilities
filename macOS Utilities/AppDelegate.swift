//
//  AppDelegate.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import PaperTrailLumberjack

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var utilitiesMenu: NSMenu?
    @IBOutlet weak var infoMenu: NSMenu?
    @IBOutlet weak var pageController: NSPageController!
    @IBOutlet weak var helpMenu: NSMenu?

    private let itemRepository = ItemRepository.shared

    private var installers = [Installer]()
    private var helpEmailAddress: String? = nil

    public let modelYearDetermination = ModelYearDetermination()
    public let pageControllerDelegate: PageController = PageController.shared
    public var preferenceLoader = PreferenceLoader(useBundlePreferences: true)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.addInstallersToInfoMenu), name: ItemRepository.newInstaller, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.readPreferences(_:)), name: PreferenceLoader.preferencesLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.showErrorAlert(notification:)), name: ErrorAlertLogger.showErrorAlert, object: nil)

        preferenceLoader = PreferenceLoader(useBundlePreferences: false)
        preferenceLoader.constructLogger()

        pageControllerDelegate.setPageController(pageController: self.pageController)

        #if DEBUG
            ItemRepository.shared.addFakeInstaller()
        #endif

        readPreferences()

        buildInfoMenu()
        ItemRepository.shared.getApplications().filter { $0.isUtility == true }.map { NSMenuItem(title: $0.name, action: #selector(openApp(sender:)), keyEquivalent: "") }.forEach { utilitiesMenu?.addItem($0) }
    }

    @objc private func showErrorAlert(notification: Notification) {
        if let errorDescription = notification.object as? String {
            showErrorAlertOnCurrentWindow(title: "Error", message: errorDescription)
        }
    }

    public func showErrorAlertOnCurrentWindow(title: String, message: String) {
        // Thank you https://github.com/sparkle-project/Sparkle/compare/1.19.0...1.20.0#diff-79d37b7d406b6534ddab8fa541dfc3e7
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.showErrorAlertOnCurrentWindow(title: title, message: message)
            }
            return
        }

        var aWindow: NSWindow? = nil

        if let keyWindow = NSApplication.shared.keyWindow {
            aWindow = keyWindow
        } else if let mainWindow = NSApplication.shared.mainWindow {
            aWindow = mainWindow
        } else if let firstWindow = NSApplication.shared.windows.first {
            aWindow = firstWindow
        }

        if let window = aWindow {
            if let contentViewController = window.contentViewController {
                contentViewController.showErrorAlert(title: title, message: message)
            }
        }
    }

    @objc private func readPreferences(_ aNotification: Notification? = nil) {
        var semaphore: DispatchSemaphore? = nil

        if let notification = aNotification {
            if notification.object != nil {
                semaphore = DispatchSemaphore(value: 1)
                DiskUtility.shared.ejectAll { (didComplete) in
                    semaphore?.signal()
                }
            }
        }

        if let validSemaphore = semaphore {
            validSemaphore.wait()
        }

        if let preferences = preferenceLoader.currentPreferences {
            let installerServer = preferences.installerServerPreferences
            mountShareFrom(installerServer)

            if let helpEmailAddress = preferences.helpEmailAddress {
                self.helpEmailAddress = helpEmailAddress
            }

            if preferences.useDeviceIdentifierAPI == true {
                DeviceIdentifier.setup(authenticationToken: preferences.deviceIdentifierAuthenticationToken!)
            }

            buildHelpMenu()
        }
    }

    public func mountShareFrom(_ installerServer: InstallerServerPreferences) {
        if installerServer.serverType == "NFS" && installerServer.isMountable() {
            DiskUtility.shared.mountNFSShare(shareURL: "\(installerServer.serverIP):\(installerServer.serverPath)", localPath: installerServer.mountPath) { (didSucceed) in
                if(didSucceed) {
                    DiskUtility.shared.mountDiskImagesAt(installerServer.mountPath)
                }
            }
        }
    }

    @objc func openApp(sender: NSMenuItem) {
        ApplicationUtility.shared.open(sender.title)
    }

    private func checkIfReadyToTerminate() {
        if applicationShouldTerminate(NSApplication.shared) == .terminateNow {
            NSApplication.shared.terminate(self)
        }
    }

    private func removeInstallersFromInfoMenu() {
        guard let infoMenu = self.infoMenu
            else {
                return
        }

        infoMenu.items.filter { $0.title.contains("Install") }.forEach { infoMenu.removeItem($0) }

        if (infoMenu.items.filter { $0 == NSMenuItem.separator() }).count > 2 {
            if let separator = (infoMenu.items.first { $0 == NSMenuItem.separator() }) {
                infoMenu.removeItem(separator)
            }
        }
    }

    @objc func startOSInstall(_ sender: NSMenuItem) {
        if let indexOfSender = infoMenu?.items.firstIndex(of: sender) {
            guard installers.indices.contains(indexOfSender) == true
                else {
                    return
            }

            let installerVersion = String(sender.title.split(separator: " ")[1])

            if let selectedInstaller = (installers.first { $0.versionNumber == installerVersion }) {
                ItemRepository.shared.setSelectedInstaller(selectedInstaller)
                pageControllerDelegate.showPageController(initialPage: 1)
            }
        }
    }

    @objc private func addInstallersToInfoMenu() {
        removeInstallersFromInfoMenu()
        installers = ItemRepository.shared.getInstallers()

        #if !DEBUG
            installers = installers.filter { $0.isFakeInstaller == false }
        #endif

        installers.forEach {
            let installerItem = NSMenuItem(title: "Install \($0.versionName)", action: #selector(AppDelegate.startOSInstall(_:)), keyEquivalent: "")
            installerItem.image = $0.canInstall ? NSImage(named: "NSStatusAvailable") : NSImage(named: "NSStatusUnavailable")
            infoMenu?.insertItem(installerItem, at: 0)
        }

        infoMenu?.insertItem(NSMenuItem.separator(), at: (installers.count))
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if(DiskUtility.shared.allSharesAndInstallersUnmounted == false) {
            DDLogInfo("Terminating application..waiting for disks to eject")
            DiskUtility.shared.ejectAll { (didComplete) in
                DDLogInfo("Finished ejecting? \(didComplete)")
                self.checkIfReadyToTerminate()
            }
            return .terminateLater
        }
        return .terminateNow
    }

    func buildHelpMenu() {
        if helpEmailAddress == nil {
            helpMenu!.items.removeAll { $0.title == "Send Log" }
            DDLogInfo("Disabling 'Send Log' menu item. helpEmailAddress is nil")
        } else {
            if (helpMenu?.items.filter { $0.title == "Send Log" })!.count == 0 {
                infoMenu?.addItem(withTitle: "Send Log", action: #selector(AppDelegate.sendLog(_:)), keyEquivalent: "")
            }
        }
    }

    func buildInfoMenu() {
        addInstallersToInfoMenu()

        if(infoMenu?.items.count ?? 0 > 0) {
            infoMenu?.addItem(NSMenuItem.separator())
        }

        infoMenu?.addItem(withTitle: Sysctl.model, action: nil, keyEquivalent: "")
        if let serial = serialNumber {
            infoMenu?.addItem(withTitle: serial, action: nil, keyEquivalent: "")
            infoMenu?.addItem(NSMenuItem.separator())
            infoMenu?.addItem(withTitle: "Check Warranty", action: #selector(AppDelegate.openCoverageLink), keyEquivalent: "")
        }
    }

    // MARK: Debug menu functions
    @IBAction func reloadPreferences(_ sender: NSMenuItem) {
        ItemRepository.shared.reloadAllItems()
    }

    @IBAction func ejectAll(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
        }
    }

    @IBAction func forceReloadAllDisks(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
            if let preferences = self.preferenceLoader.currentPreferences {
                DiskUtility.shared.mountDiskImagesAt(preferences.installerServerPreferences.mountPath)
            }
        }
    }

    @IBAction func createFakeInstallerNonInstallable(_ sender: NSMenuItem) {
        ItemRepository.shared.addFakeInstaller()
    }

    @IBAction func createFakeInstaller(_ sender: NSMenuItem) {
        ItemRepository.shared.addFakeInstaller(canInstallOnMachine: true)
    }


    // MARK: Info menu functions
    // Unfortunately, this is rate limited :/
    @objc func openCoverageLink() {
        if let serial = serialNumber {
            NSWorkspace().open(URL(string: "https://checkcoverage.apple.com/us/en/?sn=\(serial)")!)
        }
    }

    var serialNumber: String? {
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
}
