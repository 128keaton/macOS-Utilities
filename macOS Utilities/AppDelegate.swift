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
        setupMenuHandler()
    }
    
    func setupMenuHandler(){
        let menuHandler = MenuHandler.shared
        menuHandler.infoMenu = self.infoMenu
        menuHandler.helpMenu = self.helpMenu
        menuHandler.utilitiesMenu = self.utilitiesMenu
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleAppleEvent(event: replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.showErrorAlert(notification:)), name: ErrorAlertLogger.showErrorAlert, object: nil)
    }

    @objc private func showErrorAlert(notification: Notification) {
        if let errorDescription = notification.object as? String {
            NSApplication.shared.showErrorAlertOnCurrentWindow(title: "Error", message: errorDescription)
        }
    }

    @objc private func readPreferences(_ aNotification: Notification? = nil) {
        var semaphore: DispatchSemaphore? = nil
        PreferenceLoader.loaded = true
        
        if let notification = aNotification {
            if notification.object != nil {
                semaphore = DispatchSemaphore(value: 1)
                DiskUtility.shared.ejectAll() { (didComplete) in
                    semaphore?.signal()
                }
            }
        }
        
        if let validSemaphore = semaphore {
            validSemaphore.wait()
        }
        
        if let preferences = PreferenceLoader.currentPreferences {
            if let installerServer = preferences.installerServerPreferences {
                DiskUtility.shared.mountNFSShare(shareURL: "\(installerServer.serverIP):\(installerServer.serverPath)", localPath: installerServer.mountPath) { (didSucceed) in
                    if(didSucceed) {
                        DiskUtility.shared.mountDiskImagesAt(installerServer.mountPath)
                    }
                }
            }
            
            if let helpEmailAddress = preferences.helpEmailAddress {
                self.helpEmailAddress = helpEmailAddress
            }
            
            if preferences.useDeviceIdentifierAPI == true {
                DeviceIdentifier.setup(authenticationToken: preferences.deviceIdentifierAuthenticationToken!)
            }
            
           MenuHandler.shared.buildHelpMenu()
        }
    }

    private func checkIfReadyToTerminate() {
        if applicationShouldTerminate(NSApplication.shared) == .terminateNow {
            NSApplication.shared.terminate(self)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if(DiskUtility.shared.allSharesAndInstallersUnmounted == false) {
            DDLogInfo("Terminating application..waiting for disks to eject")
            DiskUtility.shared.ejectAll() { (didComplete) in
                DDLogInfo("Finished ejecting? \(didComplete)")
                self.checkIfReadyToTerminate()
            }
            return .terminateLater
        }
        return .terminateNow
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if filename.fileURL.pathExtension == "utilconf" {
            let didLoad = PreferenceLoader.loadPreferences(filename, updatingRunning: true)
            if didLoad {
                DDLogInfo("Loaded preferences from: \(filename)")
            } else {
                DDLogError("Failed to load preferences from: \(filename)")
            }

            return didLoad
        }

        return false
    }

    @objc func handleAppleEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        if let aeEventDescriptor = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) {
            if let fullURL = aeEventDescriptor.stringValue {
                let configPath = fullURL.replacingOccurrences(of: "open-utilities://", with: "")
                if configPath.contains("file://") {
                    if !PreferenceLoader.loadPreferences(configPath.replacingOccurrences(of: "file://", with: ""), updatingRunning: true) {
                        DDLogError("Could not validate configuration file \(configPath)")
                    }
                } else {
                    if let configURL = URL(string: configPath) {
                        if !PreferenceLoader.loadPreferences(configURL, updatingRunning: true) {
                            DDLogError("Could not validate configuration file \(configPath)")
                        }
                    }
                }
            }
        }
    }
}
