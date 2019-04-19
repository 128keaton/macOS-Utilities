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
    @IBOutlet weak var fileMenu: NSMenu?
    @IBOutlet weak var pageController: NSPageController!
    @IBOutlet weak var helpMenu: NSMenu?
    @IBOutlet weak var menuHandler: MenuHandler?

    private let itemRepository = ItemRepository.shared

    private var installers = [Installer]()
    private var preferencesSemaphore: DispatchSemaphore? = nil
    private var helpEmailAddress: String? = nil

    public let modelYearDetermination = ModelYearDetermination()
    public let pageControllerDelegate: PageController = PageController.shared

    public var preferenceLoader: PreferenceLoader? = PreferenceLoader()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerForNotifications()

        if let preferenceLoader = PreferenceLoader.sharedInstance {
            self.preferenceLoader = preferenceLoader
            NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.readPreferences(_:)), name: PreferenceLoader.preferencesLoaded, object: nil)
        }

        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }

        pageControllerDelegate.setPageController(pageController: self.pageController)

        readPreferences()
        setupMenuHandler()
    }

    func setupMenuHandler() {
        menuHandler?.infoMenu = self.infoMenu
        menuHandler?.helpMenu = self.helpMenu
        menuHandler?.fileMenu = self.fileMenu
        menuHandler?.utilitiesMenu = self.utilitiesMenu
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleAppleEvent(event: replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.setupMachineInformation), name: DeviceIdentifier.didSetupNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.showErrorAlert(notification:)), name: ErrorAlertLogger.showErrorAlert, object: nil)
    }

    @objc private func showErrorAlert(notification: Notification) {
        if let errorDescription = notification.object as? String {
            NSApplication.shared.showErrorAlertOnCurrentWindow(title: "Error", message: errorDescription)
        }
    }

    @objc private func readPreferences(_ aNotification: Notification? = nil) {
        PreferenceLoader.loaded = true

        if let validSemaphore = preferencesSemaphore {
            validSemaphore.wait()
        }

        preferencesSemaphore = DispatchSemaphore(value: 2)

        if let notification = aNotification {
            if notification.object != nil {
                DDLogVerbose("Will be used in the future :P")
            }
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

            if preferences.useDeviceIdentifierAPI {
                DeviceIdentifier.setup(authenticationToken: preferences.deviceIdentifierAuthenticationToken!)
            }
            if let validSemaphore = preferencesSemaphore {
                validSemaphore.signal()
            }
        } else {
            if let validSemaphore = preferencesSemaphore {
                validSemaphore.signal()
            }
        }
    }

    private func checkIfReadyToTerminate() {
        if applicationShouldTerminate(NSApplication.shared) == .terminateNow {
            NSApplication.shared.terminate(self)
        }
    }

    @objc func setupMachineInformation() {
        if let currentPreferences = PreferenceLoader.currentPreferences {
            if currentPreferences.useDeviceIdentifierAPI == true && DeviceIdentifier.isConfigured == true {
                MachineInformation.setup(deviceIdentifier: DeviceIdentifier.shared)
            }
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
