//
//  Preference.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class Preferences: Codable, NSCopying, CustomStringConvertible {
    var description: String {
        return "Preferences: \n\t Help Email Address: \(String(describing: helpEmailAddress)) \n\t DeviceIdentifier API Token: \(deviceIdentifierAuthenticationToken == nil ? "nil" : "\(deviceIdentifierAuthenticationToken!.prefix(12))...") \n\t Logging Preferences: \(String(describing: loggingPreferences))"
    }

    var helpEmailAddress: String?
    var deviceIdentifierAuthenticationToken: String?
    var loggingPreferences: LoggingPreferences?
    var installerServerPreferences: InstallerServerPreferences?
    var remoteConfigurationPreferences: [RemoteConfigurationPreferences]?
    var mappedApplications: [Application]?
    var isRemoteConfiguration: Bool? = false
    var configurationVersion: String

    var useDeviceIdentifierAPI: Bool {
        return self.deviceIdentifierAuthenticationToken != nil
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
    
    init(configurationVersion: String){
        self.configurationVersion = configurationVersion
    }
}
