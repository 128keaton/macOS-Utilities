//
//  LegacyPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class LegacyPreferences: Codable, CustomStringConvertible {

    var description: String {
        return "Legacy import use only"
    }

    var loggingEnabled: Bool
    var loggingPort: Int
    var loggingURL: String
    var applications: [String: [String: String]]
    var serverPath: String
    var serverIP: String
    var apiToken: String?
    var helpEmailAddress: String?

    func update() -> Preferences? {
        let updatedPreferences = Preferences(configurationVersion: "2.0")
        let loggingPreferences = LoggingPreferences()
        let installerServerPreferences = InstallerServerPreferences()

        // LoggingPreferences
        loggingPreferences.loggingEnabled = loggingEnabled
        loggingPreferences.loggingURL = loggingURL
        loggingPreferences.loggingPort = UInt(loggingPort)

        // InstallerServerPreferences
        installerServerPreferences.serverPath = serverPath
        installerServerPreferences.serverIP = serverIP
        installerServerPreferences.mountPath = ""
        installerServerPreferences.serverType = "NFS"
        installerServerPreferences.serverEnabled = false

        if let mappedApplications = parseApplications(applications) {
            updatedPreferences.mappedApplications = mappedApplications
        }

        if let apiToken = self.apiToken {
            updatedPreferences.deviceIdentifierAuthenticationToken = apiToken
        }

        if let helpEmailAddress = self.helpEmailAddress {
            updatedPreferences.helpEmailAddress = helpEmailAddress
        }

        updatedPreferences.loggingPreferences = loggingPreferences
        updatedPreferences.installerServerPreferences = installerServerPreferences

        return updatedPreferences
    }

    private func parseApplications(_ legacyDict: [String: [String: String]]) -> [Application]? {
        var mappedApplications = [Application]()

        for (applicationName, applicationMetadata) in legacyDict {
            if applicationMetadata.keys.contains("Path"),
                let applicationPath = applicationMetadata["Path"] {
                mappedApplications.append(Application(name: applicationName, path: applicationPath, showInApplicationsWindow: true))
            }
        }

        if mappedApplications.count > 0 {
            return mappedApplications
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case loggingEnabled = "Logging Enabled"
        case loggingPort = "Logging Port"
        case loggingURL = "Logging URL"
        case serverPath = "Server Path"
        case serverIP = "Server IP"
        case applications = "Applications"
        case helpEmailAddress = "Help Email Address"
        case apiToken = "DeviceIdentifier Authentication Token"
    }
}
