//
//  RemoteConfigurationViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/12/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class RemoteConfigurationViewController: NSViewController {
    @IBOutlet weak var remoteConfigurationURLField: NSTextField!
    @IBOutlet weak var remoteConfigurationNameField: NSTextField!
    @IBOutlet weak var fetchDoneButton: NSButton!
    @IBOutlet weak var remoteConfigurationNameLabel: NSTextField!
    @IBOutlet weak var resultsField: NSTextView!

    private let preferenceLoader = PreferenceLoader.sharedInstance

    public var remoteConfiguration: RemoteConfigurationPreferences? = nil {
        didSet {
            updateView()
        }
    }

    override func viewDidLoad() {
        updateView()
    }

    private func updateView() {
        if let remoteConfiguration = self.remoteConfiguration {
            remoteConfigurationURLField.stringValue = "\(remoteConfiguration.remoteURL)"
            remoteConfigurationNameField.stringValue = remoteConfiguration.name
            remoteConfigurationNameField.isEnabled = true
            remoteConfigurationNameLabel.setEnabled(true)
            fetchDoneButton.title = "Done"
        } else {
            remoteConfigurationNameField.isEnabled = false
            remoteConfigurationNameLabel.setEnabled(false)
            fetchDoneButton.title = "Fetch"
        }
    }

    private func getRemoteConfiguration(fromURL: URL) {
        if let fetchedRemoteConfiguration = PreferenceLoader.sharedInstance?.fetchRemoteConfiguration(fromURL) {
            if fetchedRemoteConfiguration.remoteURL.absoluteString == "http://invalid.co"{
                fetchedRemoteConfiguration.remoteURL = fromURL
            }
            
            self.remoteConfiguration = fetchedRemoteConfiguration
        } else {
            fetchDoneButton.title = "Cancel"
        }
    }

    private func saveConfiguration() {
        if let currentPreferences = PreferenceLoader.currentPreferences {
            let remoteConfiguration = self.remoteConfiguration!
            let previousRemoteConfiguration = remoteConfiguration

            if remoteConfiguration.name != remoteConfigurationNameField.stringValue {
                remoteConfiguration.name = remoteConfigurationNameField.stringValue
            }

            if let updatedURL = URL(string: remoteConfigurationURLField.stringValue),
                remoteConfiguration.remoteURL != updatedURL {
                remoteConfiguration.remoteURL = updatedURL
            }


            if currentPreferences.remoteConfigurationPreferences == nil {
                currentPreferences.remoteConfigurationPreferences = [remoteConfiguration]
            }

            if previousRemoteConfiguration != remoteConfiguration {
                if PreferenceLoader.saveRemoteConfigurationToDownloads(remoteConfiguration, fileName: "\(String.random(5))-\(remoteConfiguration.name)-remote-configuration") {
                    DDLogVerbose("Saved remote configuration!")
                } else {
                    DDLogError("Could not save remote configuration.")
                }
            }
        }
    }

    @IBAction func fetchOrFinish(_ sender: NSButton) {
        if remoteConfiguration == nil {
            if let remoteURL = URL(string: remoteConfigurationURLField.stringValue),
                remoteURL.pathExtension == "plist"{
                getRemoteConfiguration(fromURL: remoteURL)
            }else{
                DDLogError("URL cannot be blank or not point to property list!")
            }
        } else {
            saveConfiguration()
            dismiss(self)
        }
    }
}
