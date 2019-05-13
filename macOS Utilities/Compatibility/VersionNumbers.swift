//
//  VersionNumbers.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class VersionNumbers {
    static func getNameForVersion(_ versionNumber: String) -> String {
        switch versionNumber {
        case "10.9":
            return "OS X Mavericks"
        case "10.12":
            return "macOS Sierra"
        case "10.13":
            return "macOS High Sierra"
        case "10.14":
            return "macOS Mojave"
        default:
            return "OS X El Capitan"
        }
    }

    static func getVersionForName(_ name: String) -> String {
        switch name {
        case "macOS Sierra":
            return "10.12"
        case "macOS High Sierra":
            return "10.13"
        case "macOS Mojave":
            return "10.14"
        case "OS X Mavericks":
            return "10.9"
        default:
            return "10.11"

        }
    }
}
