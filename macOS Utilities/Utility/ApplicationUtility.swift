//
//  Applications.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class ApplicationUtility {
    static let shared = ApplicationUtility()

    private var allApplications = [Application]()

    public let preferenceLoader: PreferenceLoader? = (NSApplication.shared.delegate as! AppDelegate).preferenceLoader

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationUtility.getApplications(_:)), name: PreferenceLoader.preferencesLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationUtility.forceReloadApplications(_:)), name: PreferenceLoader.preferencesUpdated, object: nil)
        DDLogInfo("Initializing Applications Manager Shared Instance")
    }

    public func getUtilities() {
        let utilitiesPaths = try! FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities").sorted { $0 < $1 }
        allApplications.removeAll { $0.isUtility == true }
        allApplications.append(contentsOf: utilitiesPaths.filter { $0 != ".DS_Store" && $0 != ".localized" }.map { Application(name: $0, isUtility: true) })
    }

    @objc public func getApplications(_ notification: Notification? = nil) {
        if notification == nil {
            guard let applications = PreferenceLoader.currentPreferences?.getApplications() else { return }
            self.allApplications = []
            allApplications.append(contentsOf: applications)

            ItemRepository.shared.addToRepository(newApplications: allApplications, merge: false)
        } else if let aNotification = notification {
            DDLogVerbose("Will use this later")
            print(aNotification)
        }
    }

    @objc public func forceReloadApplications(_ notification: Notification? = nil) {
        var applications = [Application]()

        if let validNotification = notification,
            let preferences = validNotification.object as? Preferences,
            let updatedApplications = preferences.getApplications() {
            applications = updatedApplications
        } else if let updatedApplications = PreferenceLoader.currentPreferences?.getApplications() {
            applications = updatedApplications
        } else {
            return
        }

        allApplications = []

        allApplications.removeAll { $0.isUtility == false && applicationsContainsName($0.name) }
        allApplications.append(contentsOf: applications)

        ItemRepository.shared.addToRepository(newApplications: allApplications, merge: false)
    }

    public func open(_ name: String) {
        if let foundApplication = (allApplications.filter { $0.name == name }.first) {
            foundApplication.open()
        }
    }

    private func applicationsContainsName(_ name: String) -> Bool {
        if (allApplications.contains { $0.name == name }) {
            return true
        }

        return false
    }
}

