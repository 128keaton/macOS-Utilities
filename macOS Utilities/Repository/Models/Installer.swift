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
    // MARK: FakeInstaller
    public var isFakeInstaller = false
    private var fakeInstallerCanInstall = false

    private let installableVersions = ModelYearDetermination().determineInstallableVersions()

    var presentedItemURL: URL?
    var presentedItemOperationQueue: OperationQueue = OperationQueue.main
    var appLabel: String = "Not Available"
    var versionNumber: Double = 0.0
    var icon: NSImage = NSImage(named: "NSHaltIcon")!
    var versionName: String = ""
    var volumePath: String
    var isSelected = false

    var isValid: Bool {
        return appLabel != "Not Available" && versionNumber != 0.0
    }

    var id: String {
        get {
            return versionName.md5Value
        }
    }

    var canInstall: Bool {
        if(installableVersions.contains(String(self.versionNumber))) {
            DDLogInfo("\(Sysctl.model) can install \(self.versionNumber)")
        }
        return installableVersions.contains(String(self.versionNumber)) || fakeInstallerCanInstall
    }

    var comparibleVersionNumber: Int {
        return Int(String(self.versionNumber).replacingOccurrences(of: ".", with: ""))!
    }

    override var description: String {
        return isFakeInstaller ? "FakeInstaller - Can Install: \(self.canInstall) - Icon: \(icon == prohibatoryIcon ? "no" : "yes") - ID: \(self.id)" : "Installer - \(versionNumber) - \(versionName) - Icon: \(icon == prohibatoryIcon ? "no" : "yes") - Valid: \(isValid) - Can Install: \(self.canInstall) - ID: \(self.id)"
    }


    init(volumePath: String, mountPoint: URL, appName: String) {
        self.volumePath = volumePath
        self.presentedItemURL = mountPoint
        self.appLabel = "\(appName).app"
        
        super.init()

        self.determineVersion()
        self.findAppIcon()

        self.addToRepo()
    }

    init(isFakeInstaller: Bool = true, canInstallOnMachine: Bool) {
        if(isFakeInstaller) {
            self.volumePath = ""
            super.init()
            self.isFakeInstaller = isFakeInstaller
            let fakeVersionString = String.random(4, numericOnly: true)
            self.versionName = "Fake-Installer-\(fakeVersionString)"
            self.appLabel = "Fake-Installer-\(fakeVersionString).app"
            self.versionNumber = Double(fakeVersionString)!
            self.fakeInstallerCanInstall = canInstallOnMachine
            self.icon = NSImage(named: "NSDefaultInstallerIcon")!

            if(!canInstall) {
                DispatchQueue.main.async {
                    self.icon.lockFocus()
                    self.icon = self.icon.darkened()!
                    self.icon.unlockFocus()
                }
            }

            self.addToRepo()
        } else {
            DDLogError("FakeInstaller initializer called with isFakeInstaller == false. FakeInstaller initializer should only be called with isFakeInstaller == true")
            fatalError("FakeInstaller initializer called with isFakeInstaller == false. FakeInstaller initializer should only be called with isFakeInstaller == true")
        }
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

    private func determineVersion() {
        let parsedName = self.appLabel.replacingOccurrences(of: ".[0-9].*", with: "", options: .regularExpression).replacingOccurrences(of: ".app", with: "")
        self.versionNumber = Double(VersionNumbers.getVersionForName(parsedName))!
        self.versionName = parsedName
    }

    public func launch() {
        DDLogInfo("Launching installer \(self) at path \(self.presentedItemURL?.absoluteString ?? "Invalid path")")
        DispatchQueue.main.async {
            NSWorkspace.shared.open(self.presentedItemURL!.appendingPathComponent(self.appLabel))
        }
    }

    public func refresh() {
        DispatchQueue.main.sync {
            self.findAppIcon()
        }
    }

    private func findAppIcon() {
        var path = "\(volumePath)/\(self.appLabel)/Contents/Info.plist"
        var infoDictionary = NSDictionary()

        if let potentialInfoDictionary = NSDictionary(contentsOfFile: path) {
            infoDictionary = potentialInfoDictionary
        } else if let potentialInfoDictionary = NSDictionary(contentsOfFile: "/Volumes/\(self.versionName)\(path)") {
            infoDictionary = potentialInfoDictionary
            path = "/Volumes/\(self.versionName)\(path)"
        } else {
            self.icon = prohibatoryIcon!
            return
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                self.icon = prohibatoryIcon!
                return
        }

        var imagePath = "\(volumePath)/\(self.appLabel)/Contents/Resources/\(imageName)"

        if !imageName.contains(".icns") {
            imagePath = imagePath + ".icns"
        }

        self.icon = NSImage(contentsOfFile: imagePath)!
    }


    static func == (lhs: Installer, rhs: Installer) -> Bool {
        return lhs.versionNumber == rhs.versionNumber &&
            lhs.versionName == rhs.versionName
    }
}
