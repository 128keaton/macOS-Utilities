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
    @IBOutlet weak var loggingSectionLabel: NSTextField!
    @IBOutlet weak var loggingURLField: NSTextField!
    @IBOutlet weak var loggingPortField: NSTextField!
    @IBOutlet weak var loggingURLLabel: NSTextField!
    @IBOutlet weak var loggingPortLabel: NSTextField!
    @IBOutlet weak var loggingCheckBox: NSButton!

    @IBOutlet weak var installerSectionLabel: NSTextField!
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
    @IBOutlet weak var applicationsCountLabel: NSTextField!

    @IBOutlet weak var remoteConfigurationPreferencesPopup: NSPopUpButton!
    @IBOutlet weak var remoteConfigurationAmountLabel: NSTextField!

    public var preferenceLoader: PreferenceLoader? = nil
    private var preferences: Preferences? = nil {
        didSet {
            updateView()
        }
    }

    private var serverTypes = ["NFS"]

    override func awakeFromNib() {
        if let preferenceLoader = PreferenceLoader.sharedInstance {
            self.preferenceLoader = preferenceLoader

            NotificationCenter.default.addObserver(self, selector: #selector(PreferencesViewController.readPreferences), name: PreferenceLoader.preferencesLoaded, object: nil)

            if(preferences == nil) {
                readPreferences()
            }
        }
    }

    override func viewDidLoad() {
        if let ourPreferences = self.preferences {
            if PreferenceLoader.isDifferentFromRunning(ourPreferences) {
                readPreferences()
            }
        } else {
            readPreferences()
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "editApplications" {
            if let destinationViewController = segue.destinationController as? PreferencesApplicationsViewController,
                let preferences = self.preferences {
                destinationViewController.preferencesViewController = self
                destinationViewController.preferences = preferences
            }
        }
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window!.styleMask.remove(.resizable)
        updateView()
    }

    public func configureView() {
        let serverEnabled = false
        let loggingEnabled = false

        installerServerIPField.isEnabled = serverEnabled
        installerServerIPLabel.setEnabled(serverEnabled)

        installerServerPathField.isEnabled = serverEnabled
        installerServerPathLabel.setEnabled(serverEnabled)

        installerMountPathField.isEnabled = serverEnabled
        installerMountPathLabel.setEnabled(serverEnabled)

        installerServerTypePopup.isEnabled = serverEnabled
        installerMountTypeLabel.setEnabled(serverEnabled)

        loggingURLField.isEnabled = loggingEnabled
        loggingURLLabel.setEnabled(loggingEnabled)

        loggingPortField.isEnabled = loggingEnabled
        loggingPortLabel.setEnabled(loggingEnabled)

        updateOtherLabels()
    }

    public func updateOtherLabels() {
        if let sharedPreferenceLoader = PreferenceLoader.sharedInstance {
            savePathLabel.stringValue = sharedPreferenceLoader.getSaveDirectoryPath(relativeToUser: true)

            if(savePathLabel.stringValue.count > 25) {
                savePathLabel.font = NSFont.systemFont(ofSize: 10)
            } else {
                savePathLabel.font = NSFont.systemFont(ofSize: 12)
            }
        }

        if let validPreferences = preferences,
            let retreivedApplications = validPreferences.getApplications() {
            if retreivedApplications.count > 0 {
                applicationsCountLabel.stringValue = "\(retreivedApplications.count) application(s)"
                return
            }
        }
        applicationsCountLabel.stringValue = "No applications configured"
    }

    public func updateView() {
        DispatchQueue.main.async {
            if let preferences = self.preferences {
                if let loggingPreferences = preferences.loggingPreferences {
                    self.updateLoggingView(loggingPreferences)
                } else {
                    self.loggingCheckBox.state = .off
                }

                if let installerServerPreferences = preferences.installerServerPreferences {
                    self.updateInstallerView(installerServerPreferences)
                } else {
                    self.installerCheckBox.state = .off
                }

                if let helpEmailAddress = preferences.helpEmailAddress {
                    self.sendLogAddressField.stringValue = helpEmailAddress
                } else {
                    self.sendLogAddressField.stringValue = ""
                }

                if let deviceIdentifierAPIToken = preferences.deviceIdentifierAuthenticationToken {
                    self.deviceIdentifierAPITokenField.stringValue = deviceIdentifierAPIToken
                } else {
                    self.deviceIdentifierAPITokenField.stringValue = ""
                }

                self.updateOtherLabels()
            }
        }
    }

    private func updateLoggingView(_ loggingPreferences: LoggingPreferences) {
        let loggingEnabled = loggingPreferences.loggingEnabled

        loggingCheckBox.state = loggingEnabled ? .on : .off

        loggingURLField.isEnabled = loggingEnabled
        loggingURLLabel.setEnabled(loggingEnabled)

        loggingPortField.isEnabled = loggingEnabled
        loggingPortLabel.setEnabled(loggingEnabled)

        if loggingPreferences.isValid() {
            loggingURLField.stringValue = loggingPreferences.loggingURL
            loggingPortField.stringValue = "\(loggingPreferences.loggingPort)"
        }
    }

    private func updateInstallerView(_ installerServerPreferences: InstallerServerPreferences) {
        let serverEnabled = installerServerPreferences.serverEnabled

        installerCheckBox.state = serverEnabled ? .on : .off

        installerServerIPField.isEnabled = serverEnabled
        installerServerIPLabel.setEnabled(serverEnabled)

        installerServerPathField.isEnabled = serverEnabled
        installerServerPathLabel.setEnabled(serverEnabled)

        installerMountPathField.isEnabled = serverEnabled
        installerMountPathLabel.setEnabled(serverEnabled)

        installerServerTypePopup.isEnabled = serverEnabled
        installerMountTypeLabel.setEnabled(serverEnabled)

        installerServerIPField.stringValue = installerServerPreferences.serverIP
        installerServerPathField.stringValue = installerServerPreferences.serverPath
        installerMountPathField.stringValue = installerServerPreferences.mountPath

        serverTypes.forEach { installerServerTypePopup.addItem(withTitle: $0) }
        
        if let serverType = serverTypes.firstIndex(of: installerServerPreferences.serverType) {
            installerServerTypePopup.selectItem(at: serverType)
        }
        
        installerServerTypePopup.isEnabled = (serverTypes.count > 1)
    }

    @IBAction func installerCheckboxToggled(_ sender: NSButton) {
        if let preferences = self.preferences {
            if let installerServerPreferences = preferences.installerServerPreferences {
                installerServerPreferences.serverEnabled = (sender.state == .off ? false : true)
                updateInstallerView(installerServerPreferences)
            } else {
                let newInstallerServerPreferences = InstallerServerPreferences()
                preferences.installerServerPreferences = newInstallerServerPreferences
                updateInstallerView(newInstallerServerPreferences)
            }
        }
    }

    @IBAction func loggingCheckboxToggled(_ sender: NSButton) {
        if let preferences = self.preferences {
            if let loggingPreferences = preferences.loggingPreferences {
                loggingPreferences.loggingEnabled = (sender.state == .off ? false : true)
                updateLoggingView(loggingPreferences)
            } else {
                let newLoggingPreferences = LoggingPreferences()
                preferences.loggingPreferences = newLoggingPreferences
                updateLoggingView(newLoggingPreferences)
            }
        }
    }

    @objc public func readPreferences() {
        if let preferences = PreferenceLoader.currentPreferences {
            self.preferences = preferences
        }
    }

    private func savePreferences() {
        if let preferences = self.preferences,
            let installerServerPreferences = preferences.installerServerPreferences,
            let loggingPreferences = preferences.loggingPreferences,
            let validPreferenceLoader = self.preferenceLoader {

            installerServerPreferences.serverIP = installerServerIPField.stringValue
            installerServerPreferences.serverPath = installerServerPathField.stringValue
            installerServerPreferences.mountPath = installerMountPathField.stringValue

            loggingPreferences.loggingURL = loggingURLField.stringValue
            loggingPreferences.loggingPort = UInt(loggingPortField.stringValue) ?? 0

            preferences.helpEmailAddress = sendLogAddressField.stringValue
            preferences.deviceIdentifierAuthenticationToken = deviceIdentifierAPITokenField.stringValue

            if let serverType = installerServerTypePopup.selectedItem?.title {
                installerServerPreferences.serverType = serverType
            }

            validPreferenceLoader.save(preferences)
        }
    }
    
    @IBAction func closePreferences(_ sender: NSButton) {
        savePreferences()
        self.view.window?.windowController?.close()
    }

    @IBAction func clearAllPreferences(_ sender: NSButton) {
        if showConfirmationAlert(question: "Confirmation", text: "Are you sure you want to clear all of your preferences?") {
            if let preferences = self.preferences {
                preferences.reset()

                PreferenceLoader.save(preferences)

                NotificationCenter.default.post(name: ItemRepository.updatingApplications, object: [])
                configureView()
            }
        }
    }

    @IBAction func openSavePath(_ sender: NSButton) {
        sender.state = .off
        NSWorkspace.shared.open(URL(fileURLWithPath: (PreferenceLoader.libraryFolder), isDirectory: true))
    }

    @IBAction func setServerHostToCurrentIPAddress(_ sender: NSButton) {
        IPAddressChooserDialog.show(self) { (selectedIPAddress) in
            self.installerServerIPField.stringValue = selectedIPAddress
        }
    }
}
