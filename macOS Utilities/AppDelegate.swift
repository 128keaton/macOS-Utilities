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

    private var currentPageIndex = 0

    let modelYearDetermination = ModelYearDetermination()

    private var loadingViewController: LoadingViewController? = nil
    private let itemRepository = ItemRepository.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        buildInfoMenu()

        pageController.arrangedObjects = ["installSelectorController", "diskSelectorController", "loadingViewController"]
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


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if(DiskUtility.shared.allSharesAndInstallersUnmounted == false) {
            DiskUtility.shared.ejectAll { (didComplete) in
                DDLogInfo("Finished ejecting? \(didComplete)")
                self.checkIfReadyToTerminate()
            }
            return .terminateLater
        }

        return .terminateNow
    }

    func buildInfoMenu() {
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
}
extension AppDelegate: NSPageControllerDelegate {
    public func showPageController(initialPage: Int = 0) {
        if let mainWindow = NSApplication.shared.mainWindow {
            if let mainViewController = mainWindow.contentViewController {
                mainViewController.presentAsSheet(self.pageController)
            }
        }
    }

    public func goToPage(_ page: Int) {
        if pageController.arrangedObjects.indices.contains(page) {
            currentPageIndex = page
            NSAnimationContext.runAnimationGroup({ (_) in
                self.pageController.animator().selectedIndex = page
            }) {
                self.pageController.completeTransition()
            }
        } else {
            DDLogInfo("Cannot change")
        }
    }

    public func goToNextPage() {
        if pageController.arrangedObjects.indices.contains(currentPageIndex + 1) {
            currentPageIndex += 1
            self.goToPage(currentPageIndex)
        } else {
            dismissPageController()
        }
    }

    public func goToPreviousPage() {
        if pageController.arrangedObjects.indices.contains(currentPageIndex - 1) {
            currentPageIndex -= 1
            self.goToPage(currentPageIndex)
        } else {
            dismissPageController()
        }
    }

    public func dismissPageController(savePosition: Bool = false) {
        if !savePosition {
            currentPageIndex = 0
        }

        DDLogInfo("Dismissing NSPageController: \(String(describing: pageController!))")
        self.pageController.dismiss(self)
    }

    public func goToLoadingPage(loadingText: String = "Loading") {
        let objectIdentifiers = (self.pageController.arrangedObjects.map { ($0 as? String) }.compactMap { $0 })

        if let loadingPageIndex = objectIdentifiers.firstIndex(of: "loadingViewController") {
            if let _loadingViewController = self.loadingViewController {
                _loadingViewController.loadingText = loadingText
            } else {
                let _loadingViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "loadingViewController") as? LoadingViewController
                _loadingViewController?.loadingText = loadingText
                self.loadingViewController = _loadingViewController
            }

            goToPage(loadingPageIndex)
        } else {
            DDLogInfo("loadingViewController identifier not present in arrangedObjects \(self.pageController.arrangedObjects)")
        }
    }

    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> String {
        if let identifier = object as? String {
            return identifier
        }
        DDLogError("Object \(object) not string")
        return String()
    }

    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: String) -> NSViewController {
        let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: identifier) as! NSViewController

        if(identifier == "loadingViewController" && self.loadingViewController == nil) {
            self.loadingViewController = viewController as? LoadingViewController
        } else if(identifier == "loadingViewController" && self.loadingViewController != nil) {
            return self.loadingViewController! as NSViewController
        }

        return viewController
    }

    func pageControllerDidEndLiveTransition(_ pageController: NSPageController) {
        DDLogInfo("Page Controller changed pages to \(pageController.arrangedObjects[currentPageIndex])")
        self.pageController?.completeTransition()
    }
}
