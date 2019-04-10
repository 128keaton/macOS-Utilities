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

    private var stopIcon = NSImage(named: "stop")!
    private let installableVersions = ModelYearDetermination().determineInstallableVersions()

    var presentedItemURL: URL?
    var presentedItemOperationQueue: OperationQueue = OperationQueue.main
    var appLabel: String = "Not Available"
    var versionNumber: String = "0.0"
    var icon: NSImage = NSImage(named: "stop")!
    var versionName: String = ""
    var volume: Volume? = nil
    var isSelected = false

    var isValid: Bool {
        return appLabel != "Not Available" && versionNumber != "0.0"
    }

    var id: String {
        get {
            return versionNumber.md5Value
        }
    }

    var canInstall: Bool {
        if(installableVersions.contains(self.versionNumber)) {
            DDLogInfo("\(Sysctl.model) can install \(self.versionNumber)")
        }
        return installableVersions.contains(self.versionNumber) || fakeInstallerCanInstall
    }

    var comparibleVersionNumber: Int {
        return Int(versionNumber.replacingOccurrences(of: ".", with: ""))!
    }

    override var description: String {
        return isFakeInstaller ? "FakeInstaller - Can Install: \(self.canInstall) - Icon: \(icon == stopIcon ? "no" : "yes") - ID: \(self.id)" : "Installer - \(versionNumber) - \(versionName) - Icon: \(icon == stopIcon ? "no" : "yes") - Valid: \(isValid) - Can Install: \(self.canInstall) - ID: \(self.id)"
    }

    init(volume: Volume) {
        self.volume = volume
        super.init()

        self.versionName = self.getVersionName()
        self.appLabel = self.versionName + ".app"
        self.icon = self.findAppIcon()

        self.presentedItemURL = URL(fileURLWithPath: "\(self.volume!.mountPoint)", isDirectory: false)

        self.addToRepo()
    }

    init(isFakeInstaller: Bool = true, canInstallOnMachine: Bool) {
        if(isFakeInstaller) {
            super.init()
            self.isFakeInstaller = isFakeInstaller
            self.versionName = "Fake Installer"
            self.appLabel = "Fake Installer.app"
            self.versionNumber = String.random(10, numericOnly: true)
            self.fakeInstallerCanInstall = canInstallOnMachine
            self.icon = NSImage(named: "FakeInstallerIcon")!
            
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

    private func getVersionName() -> String {
        let parsedName = self.volume!.volumeName.replacingOccurrences(of: ".[0-9].*", with: "", options: .regularExpression)
        self.versionNumber = VersionNumbers.getVersionForName(parsedName)
        return parsedName
    }

    public func launch() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "\(self.volume!.mountPoint)/\(versionName).app"))
    }

    public func refresh() {
        DispatchQueue.main.sync {
            self.icon = self.findAppIcon()
            NotificationCenter.default.post(name: ItemRepository.newInstaller, object: nil)
        }
    }

    private func findAppIcon() -> NSImage {
        let path = "\(self.volume!.mountPoint)/\(self.appLabel)/Contents/Info.plist"
        guard let infoDictionary = NSDictionary(contentsOfFile: path)
            else {
                return prohibatoryIcon!
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                return prohibatoryIcon!
        }

        var imagePath = "\(self.volume!.mountPoint)/\(self.appLabel)/Contents/Resources/\(imageName)"

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
