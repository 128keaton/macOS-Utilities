//
//  VersionNumbers.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class VersionNumbers{
    func getNameForVersion(_ versionNumber: String) -> String {
        switch versionNumber {
        case "10.12":
            return "Install macOS Sierra"
        case "10.13":
            return "Install macOS High Sierra"
        case "10.14":
            return "Install macOS Mojave"
        default:
            return "Install OS X El Capitan"
            
        }
    }
    
    func getVersionForName(_ name: String) -> String{
        switch name {
        case "Install macOS Sierra":
            return "10.12"
        case "Install macOS High Sierra":
            return "10.13"
        case "Install macOS Mojave":
            return "10.14"
        default:
            return "10.11"
            
        }
    }
}
