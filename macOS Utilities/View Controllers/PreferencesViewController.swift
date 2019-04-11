//
//  PreferencesViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import AppFolder

class PreferencesViewController: NSViewController {
    @IBOutlet weak var loggingURLField: NSTextField!
    @IBOutlet weak var loggingPortField: NSTextField!
    @IBOutlet weak var loggingURLLabel: NSTextField!
    @IBOutlet weak var loggingPortLabel: NSTextField!
    @IBOutlet weak var loggingCheckBox: NSButton!


    @IBOutlet weak var installerMountPathField: NSTextField!
    @IBOutlet weak var installerServerIPField: NSTextField!
    @IBOutlet weak var installerServerPathField: NSTextField!
    @IBOutlet weak var installerServerTypePopup: NSPopUpButton!
    @IBOutlet weak var installerMountPathLabel: NSTextField!
    @IBOutlet weak var installerServerIPLabel: NSTextField!
    @IBOutlet weak var installerServerPathLabel: NSTextField!
    @IBOutlet weak var installerMountTypeLabel: NSTextField!
    @IBOutlet weak var installerCheckBox: NSButton!

    @IBOutlet weak var sendLogAddressField: NSTextField!
    @IBOutlet weak var deviceIdentifierAPITokenField: NSTextField!
    @IBOutlet weak var savePathLabel: NSTextField!

    public let preferenceLoader: PreferenceLoader = (NSApplication.shared.delegate as! AppDelegate).preferenceLoader
    private var preferences: Preferences? = nil {
        didSet {
            updateView()
        }
    }

    private var serverTypes = ["NFS"]

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(PreferencesViewController.readPreferences), name: PreferenceLoader.preferencesLoaded, object: nil)

        if(preferences == nil) {
            readPreferences()
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "editApplications" {
            if let destinationViewController = segue.destinationController as? PreferencesApplicationsViewController,
                let preferences = self.preferences {
                destinationViewController.applications = preferences.applications
                destinationViewController.preferencesViewController = self
            }
        }
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window!.styleMask.remove(.resizable)
        savePathLabel.stringValue = AppFolder.Library.url.appendingPathComponent("ER2", isDirectory: true).absoluteString.replacingOccurrences(of: "file://", with: "")
    }

    public func updateView() {
        DispatchQueue.main.async {
            if let preferences = self.preferences {
                self.updateLoggingView(preferences.loggingPreferences)
                self.updateInstallerView(preferences.installerServerPreferences)

                if let helpEmailAddress = preferences.helpEmailAddress {
                    self.sendLogAddressField.stringValue = helpEmailAddress
                }

                if let deviceIdentifierAPIToken = preferences.deviceIdentifierAuthenticationToken {
                    self.deviceIdentifierAPITokenField.stringValue = deviceIdentifierAPIToken
                }
            }
        }
    }

    private func updateLoggingView(_ loggingPreferences: LoggingPreferences) {
        loggingCheckBox.state = loggingPreferences.loggingEnabled ? .on : .off

        loggingURLField.isEnabled = loggingPreferences.loggingEnabled
        loggingPortField.isEnabled = loggingPreferences.loggingEnabled

        loggingURLField.stringValue = loggingPreferences.loggingURL
        loggingPortField.stringValue = "\(loggingPreferences.loggingPort)"
    }

    private func updateInstallerView(_ installerServerPreferences: InstallerServerPreferences) {
        installerCheckBox.state = installerServerPreferences.serverEnabled ? .on : .off

        installerServerIPField.isEnabled = installerServerPreferences.serverEnabled
        installerServerPathField.isEnabled = installerServerPreferences.serverEnabled
        installerMountPathField.isEnabled = installerServerPreferences.serverEnabled
        installerServerTypePopup.isEnabled = installerServerPreferences.serverEnabled

        installerServerIPField.stringValue = installerServerPreferences.serverIP
        installerServerPathField.stringValue = installerServerPreferences.serverPath
        installerMountPathField.stringValue = installerServerPreferences.mountPath

        serverTypes.forEach { installerServerTypePopup.addItem(withTitle: $0) }
        installerServerTypePopup.selectItem(at: serverTypes.firstIndex(of: installerServerPreferences.serverType)!)
    }

    @IBAction func installerCheckboxToggled(_ sender: NSButton) {
        if let preferences = self.preferences {
            preferences.installerServerPreferences.serverEnabled = (sender.state == .off ? false : true)
            updateInstallerView(preferences.installerServerPreferences)
        }
    }

    @IBAction func loggingCheckboxToggled(_ sender: NSButton) {
        if let preferences = self.preferences {
            preferences.loggingPreferences.loggingEnabled = (sender.state == .off ? false : true)
            updateLoggingView(preferences.loggingPreferences)
        }
    }

    @objc public func readPreferences() {
        if let preferences = preferenceLoader.currentPreferences {
            self.preferences = preferences
        }
    }

    private func savePreferences() {
        if var preferences = self.preferences {
            preferences.installerServerPreferences.serverIP = installerServerIPField.stringValue
            preferences.installerServerPreferences.serverPath = installerServerPathField.stringValue
            preferences.installerServerPreferences.mountPath = installerMountPathField.stringValue

            preferences.loggingPreferences.loggingURL = loggingURLField.stringValue
            preferences.loggingPreferences.loggingPort = UInt(loggingPortField.stringValue)!

            preferences.helpEmailAddress = sendLogAddressField.stringValue
            preferences.deviceIdentifierAuthenticationToken = deviceIdentifierAPITokenField.stringValue

            if let serverType = installerServerTypePopup.selectedItem?.title {
                preferences.installerServerPreferences.serverType = serverType
            }

            preferenceLoader.save(preferences)
        }

    }

    @IBAction func openSavePath(_ sender: NSButton) {
        sender.state = .off
        NSWorkspace.shared.open(AppFolder.Library.url.appendingPathComponent("ER2", isDirectory: true))
    }

    override func viewWillDisappear() {
        savePreferences()
    }
}
