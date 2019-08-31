//
//  AppDelegate.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import PaperTrailLumberjack
import AVFoundation
import Bugsnag

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var utilitiesMenu: NSMenu?
    @IBOutlet weak var infoMenu: NSMenu?
    @IBOutlet weak var fileMenu: NSMenu?
    @IBOutlet weak var pageController: NSPageController!
    @IBOutlet weak var helpMenu: NSMenu?
    @IBOutlet weak var preferencesMenuItem: NSMenuItem?
    @IBOutlet weak var menuHandler: MenuHandler?

    private let itemRepository = ItemRepository.shared

    private var installers = [Installer]()
    private var preferencesSemaphore: DispatchSemaphore? = nil
    private var helpEmailAddress: String? = nil
    private var waitingDialog: NSWindowController? = nil

    public let modelYearDetermination = ModelYearDetermination()
    public let pageControllerDelegate: PageController = PageController.shared

    public var preferenceLoader: PreferenceLoader? = nil

    private (set) public var audioPlayer: AVAudioPlayer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Change me in Secrets
        Bugsnag.start(withApiKey: BUGSNAG_KEY)

        registerForNotifications()
        setupAudioPlayer()

        PreferenceLoader.setup()
        SystemProfiler.getInfo()

        if let preferenceLoader = PreferenceLoader.sharedInstance {
            self.preferenceLoader = preferenceLoader
            NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.readPreferences(_:)), name: GlobalNotifications.preferencesLoaded, object: nil)
        }

        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }

        pageControllerDelegate.setPageController(pageController: self.pageController)
        self.preferencesMenuItem?.isEnabled = false

        readPreferences()
        setupMenuHandler()

        #if DEBUG
            Bugsnag.notifyError(NSError(domain: "com.example", code: 408, userInfo: nil))
        #endif
    }

    func setupMenuHandler() {
        menuHandler?.infoMenu = self.infoMenu
        menuHandler?.helpMenu = self.helpMenu
        menuHandler?.fileMenu = self.fileMenu
        menuHandler?.preferencesMenuItem = self.preferencesMenuItem
        menuHandler?.utilitiesMenu = self.utilitiesMenu
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleAppleEvent(event: replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

        NSSetUncaughtExceptionHandler { exception in
            ExceptionHandler.handle(exception: exception)
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        PeerCommunicationService.instance.updateStatus("Idle")
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.showErrorAlert(notification:)), name: ErrorAlertLogger.showErrorAlert, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.quitNowHandler), name: GlobalNotifications.quitNow, object: nil)
    }

    @objc private func showErrorAlert(notification: Notification) {
        if let errorDescription = notification.object as? String {
            NSApplication.shared.showErrorAlertOnCurrentWindow(title: "Error", message: errorDescription)
        }
    }

    @objc private func quitNowHandler() {
        NSApplication.shared.terminate(self)
    }

    @objc private func readPreferences(_ aNotification: Notification? = nil) {
        self.preferencesMenuItem?.isEnabled = false

        if let validSemaphore = preferencesSemaphore {
            validSemaphore.wait()
        } else {
            preferencesSemaphore = DispatchSemaphore(value: 2)
        }

        if let notification = aNotification {
            if notification.object != nil {
                DDLogVerbose("Will be used in the future :P")
            }
        }

        if let preferences = PreferenceLoader.currentPreferences {
            if let installerServer = preferences.installerServerPreferences {
                DiskUtility.mountNFSShare(shareURL: "\(installerServer.serverIP):\(installerServer.serverPath)", localPath: installerServer.mountPath) { (didSucceed) in
                    if(didSucceed) {
                        HardDriveImageUtility.mountDiskImagesAt(installerServer.mountPath)
                    }
                }
            }

            if let helpEmailAddress = preferences.helpEmailAddress {
                self.helpEmailAddress = helpEmailAddress
            }

            if let validSemaphore = preferencesSemaphore {
                validSemaphore.signal()
                self.preferencesMenuItem?.isEnabled = true
            }

            if preferences.mappedApplications != nil {
                // BAD
                // BAD BAD
                // BAD BAD BAD
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: ApplicationViewController.reloadApplications, object: nil)
                }
            }
        }
    }

    private func checkIfReadyToTerminate() {
        if applicationShouldTerminate(NSApplication.shared) == .terminateNow {
            NSApplication.shared.terminate(self)
        }
    }

    private func showWaitingDialog() {
        if !Thread.isMainThread || waitingDialog != nil {
            return
        }

        closeMainWindow()
        waitingDialog = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "waitingToQuitDialog") as? NSWindowController

        if let dialog = waitingDialog {
            dialog.showWindow(self)
        }
    }

    private func closeMainWindow() {
        if let keyWindow = NSApplication.shared.keyWindow {
            keyWindow.close()
        }

        if let mainWindow = NSApplication.shared.mainWindow {
            mainWindow.close()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let validPreferences = PreferenceLoader.currentPreferences,
            let ejectDrivesOnQuit = validPreferences.ejectDrivesOnQuit,
            ejectDrivesOnQuit == true {

            if(DiskUtility.allSharesAndInstallersUnmounted == false) {
                showWaitingDialog()
                DDLogInfo("Terminating application..waiting for disks to eject")
                DiskUtility.ejectAll() { (didComplete) in
                    self.checkIfReadyToTerminate()
                }
                return .terminateCancel
            }
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

    public static func getApplicationVersion() -> String? {
        guard let dictionary = Bundle.main.infoDictionary else { return nil }
        return dictionary["CFBundleShortVersionString"] as? String
    }

    public func setupAudioPlayer() {
        let path = Bundle.main.path(forResource: "nt4", ofType: "mp3")!
        let url = URL(fileURLWithPath: path)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            NotificationCenter.default.post(name: Notification.Name("AudioPlayerReady"), object: audioPlayer)
        } catch {
            DDLogError("Unable to load file")
        }
    }

}

extension AppDelegate: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NotificationCenter.default.post(name: Notification.Name("AudioFinished"), object: nil)
    }
}
