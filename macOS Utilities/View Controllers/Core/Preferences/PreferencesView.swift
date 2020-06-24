//
//  PreferencesView.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

protocol PreferencesViewType {
    var preferenceLoader: PreferenceLoader? { get set }
    var preferences: Preferences? { get set }

    func savePreferences()
}

class PreferencesView: NSViewController, PreferencesViewType {

    public var preferenceLoader: PreferenceLoader? = nil
    public var preferences: Preferences? = nil

    public func updateView() {
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        readPreferences()
        updateView()

        PeerCommunicationService.instance.updateStatus("Configuring")
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        self.savePreferences()
    }


    override func awakeFromNib() {
        if let preferenceLoader = PreferenceLoader.sharedInstance {
            self.preferenceLoader = preferenceLoader

            NotificationCenter.default.addObserver(self, selector: #selector(readPreferences), name: GlobalNotifications.preferencesLoaded, object: nil)

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

    func openSavePath() {
        NSWorkspace.shared.open(URL(fileURLWithPath: (PreferenceLoader.libraryFolder), isDirectory: true))
    }

    func savePreferences() {
        if let validPreferenceLoader = self.preferenceLoader,
            let preferences = self.preferences {
            validPreferenceLoader.save(preferences, notify: false)
        }
    }

    func clearAllPreferences() {
        if showConfirmationAlert(question: "Confirmation", text: "Are you sure you want to clear all of your preferences?") {
            if let preferences = self.preferences {
                preferences.reset()

                PreferenceLoader.save(preferences)

                NotificationCenter.default.post(name: GlobalNotifications.reloadApplications, object: [])


                self.updateView()
            }
        }
    }

    @objc public func readPreferences() {
        if let preferences = PreferenceLoader.currentPreferences {
            self.preferences = preferences
        }
    }

}
