//
//  InstallerServerPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class InstallerServerPreferences: Codable {
    var serverPath: String
    var serverIP: String
    var serverType: String
    var mountPath: String
    var serverEnabled: Bool
    
    func isMountable() -> Bool {
        return serverPath.trimmingCharacters(in: .whitespaces) != "" && serverIP.trimmingCharacters(in: .whitespaces) != "" && mountPath.trimmingCharacters(in: .whitespaces) != ""
    }
}
