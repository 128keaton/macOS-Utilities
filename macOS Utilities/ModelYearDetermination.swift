//
//  ModelYearDetermination.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 11/20/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation

class ModelYearDetermination {
    let modelIdentifier = Sysctl.model

    func determineInstallableVersion() -> [InstallVersionNumber: InstallVersionName]? {
        if modelIdentifier.contains("MacBookPro") {
            // MacBook Pro
            let identifierDigits = getIdentifierDigitsFor("MacBookPro")
            if(identifierDigits > 91) {
                return [InstallVersionNumber.mojave: InstallVersionName.mojave]
            } else if (identifierDigits > 71) {
                return [InstallVersionNumber.highSierra: InstallVersionName.highSierra]
            }

            return nil

        } else if modelIdentifier.contains("MacBookAir") {
            // MacBook Air
            let identifierDigits = getIdentifierDigitsFor("MacBookAir")
            if(identifierDigits > 51) {
                return [InstallVersionNumber.mojave: InstallVersionName.mojave]
            } else if (identifierDigits > 31) {
                return [InstallVersionNumber.highSierra: InstallVersionName.highSierra]
            }

            return nil
        } else if modelIdentifier.contains("MacBook") {
            // MacBook
            let identifierDigits = getIdentifierDigitsFor("MacBook")
            if(identifierDigits > 81) {
                return [InstallVersionNumber.mojave: InstallVersionName.mojave]
            } else if (identifierDigits > 61) {
                return [InstallVersionNumber.highSierra: InstallVersionName.highSierra]
            }

            return nil

        } else if modelIdentifier.contains("Macmini") {
            // Mac Mini
            let identifierDigits = getIdentifierDigitsFor("Macmini")
            if(identifierDigits > 61) {
                return [InstallVersionNumber.mojave: InstallVersionName.mojave]
            } else if(identifierDigits > 41) {
                return [InstallVersionNumber.highSierra: InstallVersionName.highSierra]
            }

            return nil

        } else if modelIdentifier.contains("MacPro") {
            // Mac Pro
            let identifierDigits = getIdentifierDigitsFor("MacPro")
            if(identifierDigits > 31) {
                return [InstallVersionNumber.mojave: InstallVersionName.mojave]
            }

            return nil

        } else if modelIdentifier.contains("iMac") {
            // iMac
            let identifierDigits = getIdentifierDigitsFor("iMac")
            if(identifierDigits > 131) {
                return [InstallVersionNumber.mojave: InstallVersionName.mojave]
            } else if(identifierDigits > 101) {
                return [InstallVersionNumber.highSierra: InstallVersionName.highSierra]
            }

            return nil
        }
        return [InstallVersionNumber.highSierra: InstallVersionName.highSierra]
    }

    func getIdentifierDigitsFor(_ modelName: String) -> Int {
        return Int(modelIdentifier.replacingOccurrences(of: modelName, with: "").replacingOccurrences(of: ",", with: ""))!
    }
}

enum InstallVersionName: String {
    case mojave = "Install macOS Mojave"
    case highSierra = "Install macOS High Sierra"
}

enum InstallVersionNumber: String {
    case mojave = "10.14"
    case highSierra = "10.13"
}

