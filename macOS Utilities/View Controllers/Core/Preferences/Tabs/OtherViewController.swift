//
//  OtherViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class OtherViewController: PreferencesView {
    @IBOutlet weak var printServerAddressField: NSTextField!
    @IBOutlet weak var sendLogAddressField: NSTextField!
    @IBOutlet weak var savePathLabel: NSTextField!
    @IBOutlet weak var ejectDrivesOnQuitCheckbox: NSButton!

    override func updateView() {
        if let sharedPreferenceLoader = PreferenceLoader.sharedInstance {
            savePathLabel.stringValue = sharedPreferenceLoader.getSaveDirectoryPath(relativeToUser: true)

            if(savePathLabel.stringValue.count > 25) {
                savePathLabel.font = NSFont.systemFont(ofSize: 10)
            } else {
                savePathLabel.font = NSFont.systemFont(ofSize: 12)
            }
        }

        if let validPreferences = preferences {
            if let ejectDrivesOnQuit = validPreferences.ejectDrivesOnQuit {
                ejectDrivesOnQuitCheckbox.state = ejectDrivesOnQuit ? .on : .off
            } else {
                ejectDrivesOnQuitCheckbox.state = .off
            }

            self.printServerAddressField.stringValue = validPreferences.printServerAddress ?? ""
            self.sendLogAddressField.stringValue = validPreferences.helpEmailAddress ?? ""
        }

    }

    override func savePreferences() {
        if let preferences = self.preferences {
            preferences.ejectDrivesOnQuit = self.ejectDrivesOnQuitCheckbox.state == .on
            preferences.printServerAddress = self.printServerAddressField.stringValue
            preferences.helpEmailAddress = self.sendLogAddressField.stringValue
        }

        super.savePreferences()
    }


    @IBAction func showConfigurationInFinder(_ sender: NSButton) {
        self.openSavePath()
    }
    
    @IBAction func clearPreferences(_ sender: NSButton) {
        self.clearAllPreferences()
    }
}
