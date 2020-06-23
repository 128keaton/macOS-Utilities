//
//  Version.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class Version: Equatable, ExpressibleByStringLiteral, CustomStringConvertible {
    var number: Double
    var name: String

    static let fakeInstall = Version.init(versionName: "Fake Installer Version")

    static let mavericks = Version.init(stringLiteral: "OS X Mavericks,10.9")
    static let yosemite = Version.init(stringLiteral: "OS X Yosemite,10.10")
    static let elCapitan = Version.init(stringLiteral: "OS X El Capitan,10.11")
    static let sierra = Version.init(stringLiteral: "macOS Sierra,10.12")
    static let highSierra = Version.init(stringLiteral: "macOS High Sierra,10.13")
    static let mojave = Version.init(stringLiteral: "macOS Mojave,10.14")
    static let catalina = Version.init(stringLiteral: "macOS Catalina,10.15")


    public static func == (lhs: Version, rhs: Version) -> Bool {
        return (lhs.number == rhs.number && lhs.name == rhs.name)
    }

    var description: String {
        return "\(self.name) - \(self.number)"
    }

    var sortNumber: NSNumber {
        return Int(number * 100.0) as NSNumber
    }

    var needsAPFS: Bool {
        return self.number >= 10.13
    }

    init(versionName: String) {
        if versionName.contains("Mavericks") {
            self.number = 10.9
        } else if versionName.contains("Yosemite") {
            self.number = 10.10
        } else if versionName.contains("El Capitan") {
            self.number = 10.11
        } else if versionName.contains("High Sierra") {
            self.number = 10.13
        } else if versionName.contains("Sierra") {
            self.number = 10.12
        } else if versionName.contains("Mojave") {
            self.number = 10.14
        } else if versionName.contains("Catalina") {
            self.number = 10.15
        } else if versionName.contains("Fake") {
            self.number = Double.random(in: 1.0 ... 9.0)
        } else {
            self.number = 0.0
        }

        self.name = versionName
    }

    required public init(stringLiteral value: String) {
        let components = value.components(separatedBy: ",")
        if components.count == 2 {
            self.name = components[0]
            self.number = Double(components[1]) ?? 0.0
        } else {
            self.name = ""
            self.number = 0.0
        }
    }
}
