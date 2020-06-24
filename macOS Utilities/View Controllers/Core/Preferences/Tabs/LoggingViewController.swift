//
//  LoggingViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class LoggingViewController: PreferencesView {
    @IBOutlet weak var loggingURLField: NSTextField!
    @IBOutlet weak var loggingPortField: NSTextField!
    @IBOutlet weak var loggingURLLabel: NSTextField!
    @IBOutlet weak var loggingPortLabel: NSTextField!
    @IBOutlet weak var loggingCheckbox: NSButton!

    public override func updateView() {
        DispatchQueue.main.async {
            if let preferences = self.preferences {
                if let loggingPreferences = preferences.loggingPreferences {
                    self.updateLoggingView(loggingPreferences)
                } else {
                    self.loggingCheckbox.state = .off
                }
            }
        }
    }


    private func updateLoggingView(_ loggingPreferences: LoggingPreferences) {
        let loggingEnabled = loggingPreferences.loggingEnabled

        loggingCheckbox.state = loggingEnabled ? .on : .off

        loggingURLField.isEnabled = loggingEnabled
        loggingURLLabel.setEnabled(loggingEnabled)

        loggingPortField.isEnabled = loggingEnabled
        loggingPortLabel.setEnabled(loggingEnabled)

        if loggingPreferences.isValid() {
            loggingURLField.stringValue = loggingPreferences.loggingURL
            loggingPortField.stringValue = "\(loggingPreferences.loggingPort)"
        }
    }

    override func savePreferences() {
        if let preferences = self.preferences, let loggingPreferences = preferences.loggingPreferences {

            loggingPreferences.loggingEnabled = self.loggingCheckbox.state == .on
            loggingPreferences.loggingURL = self.loggingURLField.stringValue
            loggingPreferences.loggingPort = UInt(self.loggingPortField.stringValue) ?? 0
        }

        super.savePreferences()
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

}
