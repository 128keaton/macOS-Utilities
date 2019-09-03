//
//  Preference.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class Preferences: Codable, NSCopying, CustomStringConvertible, Equatable {
    var description: String {
        return "Preferences: \n\t Help Email Address: \(String(describing: helpEmailAddress)) \n\t DeviceIdentifier API Token: \(deviceIdentifierAuthenticationToken == nil ? "nil" : "\(deviceIdentifierAuthenticationToken!.prefix(12))...") \n\t Logging Preferences: \(String(describing: loggingPreferences))"
    }

    var helpEmailAddress: String?
    var printServerAddress: String?
    var deviceIdentifierAuthenticationToken: String?
    var loggingPreferences: LoggingPreferences?
    var installerServerPreferences: InstallerServerPreferences?
    var mappedApplications: [Application]?
    var isRemoteConfiguration: Bool? = false
    var ejectDrivesOnQuit: Bool? = true
    var configurationVersion: String

    var useDeviceIdentifierAPI: Bool {
        return self.deviceIdentifierAuthenticationToken != nil && self.deviceIdentifierAuthenticationToken != ""
    }

    public func getApplications() -> [Application]? {
        return mappedApplications
    }

    public func setApplications(_ applications: [Application]) {
        self.mappedApplications = applications
    }

    public func hasLoggingPreferences() -> Bool {
        return loggingPreferences != nil
    }

    public func hasInstallerServerPreferences() -> Bool {
        return loggingPreferences != nil
    }


    func copy(with zone: NSZone? = nil) -> Any {
        let data = try! PropertyListEncoder().encode(self)
        return try! PropertyListDecoder().decode(Preferences.self, from: data)
    }

    func reset() {
        self.helpEmailAddress = ""
        self.deviceIdentifierAuthenticationToken = ""
        self.loggingPreferences = nil
        self.installerServerPreferences = nil
        self.mappedApplications = nil
    }

    init(configurationVersion: String) {
        self.configurationVersion = configurationVersion
    }

    static func == (lhs: Preferences, rhs: Preferences) -> Bool {
        if(lhs.installerServerPreferences != rhs.installerServerPreferences) {
            return true
        }

        if(lhs.loggingPreferences == rhs.loggingPreferences) {
            return true
        }

        if(lhs.useDeviceIdentifierAPI == rhs.useDeviceIdentifierAPI) {
            return true
        }

        if(lhs.helpEmailAddress == rhs.helpEmailAddress) {
            return true
        }

        if(lhs.mappedApplications == rhs.mappedApplications) {
            return true
        }

        if(lhs.ejectDrivesOnQuit == rhs.ejectDrivesOnQuit) {
            return true
        }


        if let mappedApplicationsA = lhs.mappedApplications,
            let mappedApplicationsB = rhs.mappedApplications {
            return mappedApplicationsA.map { $0.showInApplicationsWindow } == mappedApplicationsB.map { $0.showInApplicationsWindow }
        }

        return false
    }
}
