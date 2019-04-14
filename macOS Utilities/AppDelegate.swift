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

    #if DEBUG
        public var preferenceLoader: PreferenceLoader? = PreferenceLoader()
    #else
        public var preferenceLoader: PreferenceLoader? = PreferenceLoader(useBundlePreferences: true)
    #endif

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerForNotifications()

        if let preferenceLoader = PreferenceLoader.sharedInstance {
            self.preferenceLoader = preferenceLoader
            NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.readPreferences(_:)), name: PreferenceLoader.preferencesLoaded, object: nil)
        }

        pageControllerDelegate.setPageController(pageController: self.pageController)

        #if DEBUG
            ItemRepository.shared.addFakeInstaller()
        #endif

        readPreferences()

        buildInfoMenu()
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.addInstallerToMenu(_:)), name: ItemRepository.newInstaller, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.showErrorAlert(notification:)), name: ErrorAlertLogger.showErrorAlert, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.addUtilityToMenu(_:)), name: ItemRepository.newUtility, object: nil)
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
        PreferenceLoader.loaded = true

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

        if let preferences = PreferenceLoader.currentPreferences {
            if let installerServer = preferences.installerServerPreferences {
                mountShareFrom(installerServer)
            }

            if let helpEmailAddress = preferences.helpEmailAddress {
                self.helpEmailAddress = helpEmailAddress
            }

            if preferences.useDeviceIdentifierAPI == true {
                DeviceIdentifier.setup(authenticationToken: preferences.deviceIdentifierAuthenticationToken!)
            }

            buildHelpMenu()
        }
    }

    @objc private func addUtilityToMenu(_ notification: Notification? = nil) {
        if let validNotification = notification {
            if let utility = validNotification.object as? Application {
                utilitiesMenu?.addItem(withTitle: utility.name, action: #selector(AppDelegate.openApp(_:)), keyEquivalent: "")
            }
        }
    }

    @objc private func addInstallerToMenu(_ notification: Notification? = nil) {
        if let infoMenu = self.infoMenu {
            if (infoMenu.items.filter { $0 == NSMenuItem.separator() }).count == 1 {
                infoMenu.insertItem(NSMenuItem.separator(), at: 0)
            }

            if let validNotification = notification {
                if let installer = validNotification.object as? Installer {
                    let installerItem = NSMenuItem(title: "Install \(installer.versionName)", action: #selector(AppDelegate.startOSInstall(_:)), keyEquivalent: "")
                    installerItem.image = installer.canInstall ? NSImage(named: "NSStatusAvailable") : NSImage(named: "NSStatusUnavailable")
                    infoMenu.insertItem(installerItem, at: 0)
                }
            }
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

    @objc func openApp(_ sender: NSMenuItem) {
        ApplicationUtility.shared.open(sender.title)
    }

    private func checkIfReadyToTerminate() {
        if applicationShouldTerminate(NSApplication.shared) == .terminateNow {
            NSApplication.shared.terminate(self)
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
                        let didLoad = PreferenceLoader.loadPreferences(propertyListURL, updatingRunning: true)
                        if didLoad{
                            DDLogInfo("Loaded preferences from: \(propertyListURL)")
                        }else{
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

    @IBAction func ejectAll(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll { (didComplete) in
            DDLogInfo("Finished ejecting? \(didComplete)")
        }
    }

    @IBAction func forceReloadAllDisks(_ sender: NSMenuItem) {
        DiskUtility.shared.ejectAll { (didComplete) in
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
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if filename.fileURL.pathExtension == "utilconf"{
            let didLoad = PreferenceLoader.loadPreferences(filename, updatingRunning: true)
            if didLoad{
                DDLogInfo("Loaded preferences from: \(filename)")
            }else{
                DDLogError("Failed to load preferences from: \(filename)")
            }
            
            return didLoad
        }
        
        return false
    }
}
