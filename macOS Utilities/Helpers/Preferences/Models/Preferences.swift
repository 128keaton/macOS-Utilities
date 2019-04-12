//
//  Preference.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class Preferences: Codable, NSCopying {
    var helpEmailAddress: String?
    var deviceIdentifierAuthenticationToken: String?
    var loggingPreferences: LoggingPreferences
    var installerServerPreferences: InstallerServerPreferences

    private var mappedApplications: [Application]

    var useDeviceIdentifierAPI: Bool {
        return self.deviceIdentifierAuthenticationToken != nil
    }

    public func getApplications() -> [Application] {
        return mappedApplications
    }
    
    public func setApplications(_ applications: [Application]){
        self.mappedApplications = applications
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let data = try! PropertyListEncoder().encode(self)
        return  try! PropertyListDecoder().decode(Preferences.self, from: data)
    }
}
