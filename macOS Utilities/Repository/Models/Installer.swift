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

class Installer: NSObject, Item, NSFilePresenter {
    private let installableVersions = ModelYearDetermination().determineInstallableVersions()

    var presentedItemURL: URL?
    var presentedItemOperationQueue: OperationQueue = OperationQueue.main
    var appLabel: String = "Not Available"
    var versionNumber: String = "0.0"
    var icon: NSImage? = nil
    var versionName: String = ""
    var volume: Volume
    var isSelected = false
    var isValid: Bool {
        return appLabel != "Not Available" && versionNumber != "0.0"
    }

    var id: String {
        get {
            return versionName.md5Value
        }
    }

    var canInstall: Bool {
        if(installableVersions.contains(self.versionNumber)) {
            DDLogInfo("\(Sysctl.model) can install \(self.versionNumber)")
        }
        return installableVersions.contains(self.versionNumber)
    }

    override var description: String {
        return "Installer - \(versionNumber) - \(versionName) - Icon: \(icon == nil ? "no" : "yes") - Valid: \(isValid)"
    }

    init(volume: Volume) {
        self.volume = volume
        super.init()

        self.versionName = self.getVersionName()
        self.appLabel = self.versionName + ".app"
        self.icon = self.findAppIcon()

        self.presentedItemURL = URL(fileURLWithPath: "\(self.volume.mountPoint)", isDirectory: false)

        self.addToRepo()
    }

    func addToRepo() {
        ItemRepository.shared.addToRepository(newInstaller: self)
    }

    func presentedSubitemDidChange(at url: URL) {
        let pathExtension = url.pathExtension

        if pathExtension == "app" {
            DDLogInfo("installer updated? \(self.description)")
        } else {
            DDLogInfo("maybe not installer updated? \(self.description)")
        }
    }

    private func getVersionName() -> String {
        let parsedName = self.volume.volumeName.replacingOccurrences(of: ".[0-9].*", with: "", options: .regularExpression)
        self.versionNumber = VersionNumbers.getVersionForName(parsedName)
        return parsedName
    }

    public func launch() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "\(self.volume.mountPoint)/\(versionName).app"))
    }

    public func refresh() {
        DispatchQueue.main.sync {
            self.icon = self.findAppIcon()
            NotificationCenter.default.post(name: ItemRepository.newInstaller, object: nil)
        }
    }

    private func findAppIcon() -> NSImage {
        let path = "\(self.volume.mountPoint)/\(self.appLabel)/Contents/Info.plist"
        guard let infoDictionary = NSDictionary(contentsOfFile: path)
            else {
                return prohibatoryIcon!
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                return prohibatoryIcon!
        }

        var imagePath = "\(self.volume.mountPoint)/\(self.appLabel)/Contents/Resources/\(imageName)"

        if !imageName.contains(".icns") {
            imagePath = imagePath + ".icns"
        }

        return NSImage(contentsOfFile: imagePath)!
    }


    static func == (lhs: Installer, rhs: Installer) -> Bool {
        return lhs.versionNumber == rhs.versionNumber &&
            lhs.versionName == rhs.versionName && lhs.icon == rhs.icon
    }
}
