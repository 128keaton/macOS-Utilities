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

    private let itemRepository = ItemRepository.shared
    private var installers = [Installer]()

    public let modelYearDetermination = ModelYearDetermination()
    public let pageControllerDelegate: PageController = PageController.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.addInstallersToInfoMenu), name: ItemRepository.newInstaller, object: nil)

        buildInfoMenu()

        pageControllerDelegate.setPageController(pageController: self.pageController)

        #if DEBUG
            ItemRepository.shared.addFakeInstaller()
        #endif


        ItemRepository.shared.getApplications().filter { $0.isUtility == true }.map { NSMenuItem(title: $0.name, action: #selector(openApp(sender:)), keyEquivalent: "") }.forEach { utilitiesMenu?.addItem($0) }

        let installersShareIP = Preferences.shared.getServerIP()
        let installersSharePath = Preferences.shared.getServerPath()
        let installersLocalPath = Preferences.shared.getMountPoint()

        DiskUtility.shared.mountNFSShare(shareURL: "\(installersShareIP):\(installersSharePath)", localPath: installersLocalPath) { (didSucceed) in
            if(didSucceed) {
                DiskUtility.shared.mountDiskImagesAt(installersLocalPath)
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
        installers = ItemRepository.shared.getInstallers().filter { $0.isFakeInstaller == false }
        installers.forEach { infoMenu?.insertItem(withTitle: "Install \($0.versionNumber) - \($0.canInstall ? "🙂" : "☹️")", action: #selector(AppDelegate.startOSInstall(_:)), keyEquivalent: "", at: 0) }
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

    func buildInfoMenu() {
        addInstallersToInfoMenu()

        if(infoMenu?.items.count ?? 0 > 0) {
            infoMenu?.addItem(NSMenuItem.separator())
        }

        infoMenu?.addItem(withTitle: Sysctl.model, action: nil, keyEquivalent: "")
        if let serial = serialNumber {
            infoMenu?.addItem(withTitle: serial, action: nil, keyEquivalent: "")
            infoMenu?.addItem(NSMenuItem.separator())
            infoMenu?.addItem(withTitle: "Check Warranty", action: #selector(AppDelegate.openSerialLink), keyEquivalent: "")
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

    @IBAction func reloadInstallers(_ sender: NSMenuItem) {
        ItemRepository.shared.getInstallers().forEach { $0.refresh() }
    }

    @IBAction func createFakeInstallerNonInstallable(_ sender: NSMenuItem) {
        ItemRepository.shared.addFakeInstaller()
    }

    @IBAction func createFakeInstaller(_ sender: NSMenuItem) {
        ItemRepository.shared.addFakeInstaller(canInstallOnMachine: true)
    }


    // MARK: Info menu functions
    // Unfortunately, this is rate limited :/
    @objc func openSerialLink() {
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
    @IBAction func setTicketEmail(_ sender: NSMenuItem) {
        let emailService = NSSharingService(named: .composeEmail)
        let logFilePaths = (DDLog.allLoggers.first { $0 is DDFileLogger } as! DDFileLogger).logFileManager.sortedLogFilePaths.map { URL(fileURLWithPath: $0) }
        let htmlContent = "<h2>Please type your issue here:<h2><br><p>Replace Me</p>".data(using: .utf8)
        
        var items: [Any] = [NSAttributedString(html: htmlContent!, options: [:], documentAttributes: nil)!]
        var emailSubject = Host.current().localizedName != nil ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__\(getSystemUUID() ?? ""))") : String("\(Sysctl.model)__(\(getSystemUUID() ?? ""))")
        
        #if DEBUG
            emailSubject = emailSubject + "__DEBUG__"
        #endif
        
        logFilePaths.forEach { items.append($0) }

        emailService?.subject = emailSubject
        emailService?.recipients = ["keaton.burleson@er2.com"]
        emailService?.perform(withItems: items)
    }
}
