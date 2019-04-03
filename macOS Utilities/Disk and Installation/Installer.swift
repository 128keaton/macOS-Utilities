//
//  InstallDisk.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class Installer: CustomStringConvertible, Equatable {
    private let installableVersions = ModelYearDetermination().determineInstallableVersions()
    var appLabel: String = "Not Available"
    var versionNumber: String = "0.0"
    var icon: NSImage? = nil
    var versionName: String = ""
    var mountedDisk: MountedDisk? = nil
    var isValid: Bool {
        return appLabel != "Not Available" && versionNumber != "0.0"
    }
    
    var canInstall: Bool {
        if(installableVersions.contains(self.versionNumber)) {
            DDLogInfo("\(Sysctl.model) can install \(self.versionNumber)")
        }
        return installableVersions.contains(self.versionNumber)
    }
    
    var description: String {
        return "Installer - \(versionNumber) - \(versionName) - Icon: \(icon == nil ? "no" : "yes") - Valid: \(isValid)"
    }

    init(mountedDisk: MountedDisk) {
        self.mountedDisk = mountedDisk
        self.versionName = self.getVersionName()
        self.appLabel = self.versionName + ".app"
        self.icon = self.findAppIcon()
    }

    private func getVersionName() -> String {
        let parsedName = self.mountedDisk!.name.replacingOccurrences(of: ".[0-9].*", with: "", options: .regularExpression)
        self.versionNumber = VersionNumbers.getVersionForName(parsedName)
        return parsedName
    }

    public func kickoffInstall() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes/\(self.mountedDisk!.name)/\(versionName).app"))
    }

    private func findAppIcon() -> NSImage {
        let path = "/Volumes/\(self.mountedDisk!.name)/\(versionName).app/Contents/Info.plist"
        guard let infoDictionary = NSDictionary(contentsOfFile: path)
            else {
                return prohibatoryIcon!
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                return prohibatoryIcon!
        }

        var imagePath = "/Volumes/\(self.mountedDisk!.name)/\(versionName).app/Contents/Resources/\(imageName)"

        if !imageName.contains(".icns") {
            imagePath = imagePath + ".icns"
        }

        return NSImage(contentsOfFile: imagePath)!
    }


    static func == (lhs: Installer, rhs: Installer) -> Bool {
        return lhs.versionNumber == rhs.versionNumber &&
            lhs.versionName == rhs.versionName
    }
}
