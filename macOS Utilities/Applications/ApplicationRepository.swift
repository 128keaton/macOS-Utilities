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

class ApplicationRepository {
    private let preferences = Preferences.shared
    private var sections = [String]()
    private var delegate: ApplicationsDelegate? = nil
    private var applications = [Application]() {
        didSet {
            self.delegate?.applicationsUpdated()
        }
    }
    private var utilities = [Application]()

    static let shared = ApplicationRepository()

    private init() {
        fetchUtilities()
        DDLogInfo("Initializing Applications Manager Shared Instance")
    }

    public func setDelegate(newDelegate: ApplicationsDelegate) {
        self.delegate = newDelegate
    }

    private func fetchUtilities() {
        let utilitiesPaths = try! FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities").sorted { $0 < $1 }
        for file in utilitiesPaths {
            if file != ".DS_Store" && file != ".localized" {
                let utility = Application(name: file, isUtility: true)
                self.utilities.append(utility)
            }
        }
    }

    public func getUtilities() -> [Application] {
        if(self.utilities.count == 0) {
            self.fetchUtilities()
        }
        return self.utilities
    }

    public func getApplications() -> [Application] {
        var updatedApplications = [Application]()

        guard let allApplications = self.getPreferenceList()["Applications"] as? [String: [String: String]]
            else {
                return self.applications
        }

        let applicationNames = Array(allApplications.keys.sorted())

        for name in applicationNames {
            if let rawApplication = allApplications[name] {
                let newApp = Application(name: name, prefDict: rawApplication)
                DDLogInfo("Adding new application with name: \(newApp.name), and path: \(newApp.path). Is invalid? \(newApp.isInvalid)")

                if(!sections.contains(newApp.sectionName)) {
                    sections.append(newApp.sectionName)
                }
                updatedApplications.append(newApp)
            }
        }

        DDLogInfo("\(updatedApplications.count) applications have been created.")

        updatedApplications = updatedApplications.sorted(by: { $0.name < $1.name })

        self.applications = updatedApplications
        return self.applications
    }

    private func getPreferenceList() -> NSDictionary {
        guard let rawPreferences = preferences.raw()
            else {
                return NSDictionary()
        }
        return rawPreferences
    }

    public func getSections() -> [String] {
        if(sections.count == 0) {
            DDLogInfo("No sections found? Trying to read plist again.")
            self.applications = getApplications()
        }

        return self.sections
    }

    public func getApplicationsForSection(section: String) -> [Application] {
        return applications.filter { $0.sectionName == section }
    }

    public func getApplicationsForSection(sectionIndex: Int) -> [Application] {
        var applicationsForSection = [Application]()
        var section = ""

        if self.sections.indices.contains(sectionIndex) {
            section = self.sections[sectionIndex]
            DDLogInfo("Retreived section: \(section)")

            applicationsForSection = applications.filter { $0.sectionName == section }
        } else {
            DDLogError("Unable to get applications for sectionIndex \(sectionIndex) because the index is out of bounds.")
        }

        DDLogInfo("Apps for section (\(section)): \(applicationsForSection.map { $0.path })")
        return applicationsForSection
    }

    public func openAppByName(_ name: String, isUtility: Bool = false) {
        if(isUtility) {
            utilities.first(where: { $0.name == name })?.open()
        } else {
            applications.first(where: { $0.name == name })?.open()
        }
    }

}
protocol ApplicationsDelegate {
    func applicationsUpdated()
}
