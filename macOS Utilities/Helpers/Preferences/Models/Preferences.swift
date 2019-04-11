//
//  Preference.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct Preferences: Codable {
    var helpEmailAddress: String?
    var deviceIdentifierAuthenticationToken: String?
    var loggingPreferences: LoggingPreferences
    var installerServerPreferences: InstallerServerPreferences
    var applications: [String: [String: String]]

    var useDeviceIdentifierAPI: Bool {
        return self.deviceIdentifierAuthenticationToken != nil
    }
}
