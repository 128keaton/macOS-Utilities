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
    static let ApplicationsChanged = NSNotification.Name("NSApplicationsChanged")
    
    private var allApplications = [Application]()

    public let preferenceLoader: PreferenceLoader? = (NSApplication.shared.delegate as! AppDelegate).preferenceLoader

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationUtility.getApplications), name: PreferenceLoader.preferencesLoaded, object: nil)
        DDLogInfo("Initializing Applications Manager Shared Instance")
    }

    public func getUtilities() {
        let utilitiesPaths = try! FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities").sorted { $0 < $1 }
        allApplications.removeAll { $0.isUtility == true }
        allApplications.append(contentsOf: utilitiesPaths.filter { $0 != ".DS_Store" && $0 != ".localized" }.map { Application(name: $0, isUtility: true) })
    }

    @objc public func getApplications(shouldClear: Bool = false) {
        guard let preferenceLoader = self.preferenceLoader else { return }
        guard let applications = preferenceLoader.currentPreferences?.applications else { return }
        
        if(shouldClear == true) {
            allApplications = []
        }

        allApplications.removeAll { $0.isUtility == false }
        allApplications.append(contentsOf: applications.map { name, prefDict in (Application(name: name, prefDict: prefDict)) })
        
        if(shouldClear == true) {
            NotificationCenter.default.post(name: ApplicationUtility.ApplicationsChanged, object: nil)
        }
    }

    public func open(_ name: String) {
        if let foundApplication = (allApplications.filter { $0.name == name }.first) {
            foundApplication.open()
        }
    }
}

