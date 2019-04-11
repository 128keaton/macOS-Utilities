//
//  LoggingPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class LoggingPreferences: Codable {
    var loggingEnabled: Bool
    var loggingPort: UInt
    var loggingURL: String
}
