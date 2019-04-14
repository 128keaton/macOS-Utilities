//
//  LoggingPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class LoggingPreferences: Codable, Equatable {
    var loggingEnabled: Bool
    var loggingPort: UInt
    var loggingURL: String

    static func == (lhs: LoggingPreferences, rhs: LoggingPreferences) -> Bool {

        let mLhs = Mirror(reflecting: lhs).children.filter { $0.label != nil }
        let mRhs = Mirror(reflecting: rhs).children.filter { $0.label != nil }

        for i in 0..<mLhs.count {
            guard let valLhs = mLhs[i].value as? GenericType, let valRhs = mRhs[i].value as? GenericType else {
                print("Invalid: Properties 'lhs.\(mLhs[i].label!)' and/or 'rhs.\(mRhs[i].label!)' are not of 'GenericType' types.")
                return false
            }
            if !valLhs.isEqualTo(other: valRhs) {
                return false
            }
        }
        return true
    }

    func isValid() -> Bool {
        return self.loggingPort != 0 && self.loggingURL != String()
    }

    static func isValid(_ loggingPreferences: LoggingPreferences) -> Bool {
        return loggingPreferences.loggingPort != 0 && loggingPreferences.loggingURL != String()
    }

    init(loggingEnabled: Bool? = true, loggingPort: UInt?, loggingURL: String?) {
        if let _enabled = loggingEnabled {
            self.loggingEnabled = _enabled
        } else {
            self.loggingEnabled = false
        }

        if let _port = loggingPort {
            self.loggingPort = _port
        } else {
            self.loggingPort = 0
        }

        if let _url = loggingURL {
            self.loggingURL = _url
        } else {
            self.loggingURL = String()
        }
    }

    convenience init() {
        self.init(loggingEnabled: true, loggingPort: nil, loggingURL: nil)
    }
}
