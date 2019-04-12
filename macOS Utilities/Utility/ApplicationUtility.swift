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
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationUtility.forceReloadApplications), name: PreferenceLoader.preferencesUpdated, object: nil)
        DDLogInfo("Initializing Applications Manager Shared Instance")
    }

    public func getUtilities() {
        let utilitiesPaths = try! FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities").sorted { $0 < $1 }
        allApplications.removeAll { $0.isUtility == true }
        allApplications.append(contentsOf: utilitiesPaths.filter { $0 != ".DS_Store" && $0 != ".localized" }.map { Application(name: $0, isUtility: true) })
    }

    @objc public func getApplications(_ notification: Notification? = nil) {
        if notification == nil{
            guard let applications = PreferenceLoader.currentPreferences?.getApplications() else { return }
            
            allApplications.append(contentsOf: applications)
            allApplications.forEach { $0.showInApplicationsWindow = true }
            
            ItemRepository.shared.addToRepository(newApplications: allApplications)
        }
    }

    @objc public func forceReloadApplications() {
        guard let applications = PreferenceLoader.currentPreferences?.getApplications() else { return }

        allApplications = []

        allApplications.removeAll { $0.isUtility == false }
        allApplications.append(contentsOf: applications)

        ItemRepository.shared.addToRepository(newApplications: allApplications)
    }

    public func open(_ name: String) {
        if let foundApplication = (allApplications.filter { $0.name == name }.first) {
            foundApplication.open()
        }
    }
}

