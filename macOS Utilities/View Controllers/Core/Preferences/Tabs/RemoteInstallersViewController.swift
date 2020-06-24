//
//  RemoteInstallersViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class RemoteInstallersViewController: PreferencesView {
    @IBOutlet weak var installerMountPathLabel: NSTextField!
    @IBOutlet weak var installerMountPathField: NSTextField!

    @IBOutlet weak var installerServerIPLabel: NSTextField!
    @IBOutlet weak var installerServerIPField: NSTextField!

    @IBOutlet weak var installerServerPathLabel: NSTextField!
    @IBOutlet weak var installerServerPathField: NSTextField!

    @IBOutlet weak var installerCheckbox: NSButton!

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

    override func updateView() {
        DispatchQueue.main.async {
            if let preferences = self.preferences {
                if let installerServerPreferences = preferences.installerServerPreferences {
                    self.updateInstallerView(installerServerPreferences)
                } else {
                    self.installerCheckbox.state = .off
                }
            }
        }
    }

    override func savePreferences() {
        if let preferences = self.preferences, let installerServerPreferences = preferences.installerServerPreferences {

            installerServerPreferences.serverEnabled = self.installerCheckbox.state == .on
            installerServerPreferences.serverIP = self.installerServerIPField.stringValue
            installerServerPreferences.serverPath = self.installerServerPathField.stringValue
            installerServerPreferences.mountPath = self.installerMountPathField.stringValue
        }

        super.savePreferences()
    }

    private func updateInstallerView(_ installerServerPreferences: InstallerServerPreferences) {
        let serverEnabled = installerServerPreferences.serverEnabled

        installerCheckbox.state = serverEnabled ? .on : .off

        installerServerIPField.isEnabled = serverEnabled
        installerServerIPLabel.setEnabled(serverEnabled)

        installerServerPathField.isEnabled = serverEnabled
        installerServerPathLabel.setEnabled(serverEnabled)

        installerMountPathField.isEnabled = serverEnabled
        installerMountPathLabel.setEnabled(serverEnabled)


        installerServerIPField.stringValue = installerServerPreferences.serverIP
        installerServerPathField.stringValue = installerServerPreferences.serverPath
        installerMountPathField.stringValue = installerServerPreferences.mountPath
    }

    @IBAction func setServerHostToCurrentIPAddress(_ sender: NSButton) {
        IPAddressChooserDialog.show(self) { (selectedIPAddress) in
            self.installerServerIPField.stringValue = selectedIPAddress
        }
    }
}
