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

class Installer: Application {
    public var isFakeInstaller = false
    private var fakeInstallerCanInstall = false
    private var alreadyDeterminedCanInstall: Bool? = nil

    private let installableVersions = ModelYearDetermination().determineInstallableVersions()

    var version: Version {
        var versionName = self.name.replacingOccurrences(of: ".app", with: "").replacingOccurrences(of: "Install ", with: "")
        if !isFakeInstaller {
            versionName = versionName.replacingOccurrences(of: ".[0-9].*", with: "", options: .regularExpression)
        }

        return Version(versionName: versionName)
    }

    var volumePath: String
    var installerPath: String

    var isSelected = false

    override var defaultIcon: NSImage {
        return NSImage(named: "NSDefaultInstallerIcon")!
    }

    override var sortNumber: NSNumber? {
        return self.version.sortNumber
    }

    override var id: String {
        get {
            return self.version.name.md5Value
        }
    }

    var canInstall: Bool {
        if let alreadyDeterminedCanInstall = self.alreadyDeterminedCanInstall {
            return alreadyDeterminedCanInstall
        }

        let installerCanInstall = fakeInstallerCanInstall == true || installableVersions.contains(self.version)

        if(installerCanInstall) {
            DDLogInfo("\(Sysctl.model) can install \(self.version)")
        }

        self.alreadyDeterminedCanInstall = installerCanInstall

        return installerCanInstall
    }

    override var description: String {
        return isFakeInstaller ? "FakeInstaller: \(self.version)" : "Installer: \(self.version)"
    }

    override func open() -> Bool {
        if canInstall && !isFakeInstaller {
            return super.open()
        } else if isFakeInstaller {
            return true
        }

        DDLogError("\(Sysctl.model) cannot install \(self.version)")
        return false
    }

    init(volumePath: String, appName: String, addToRepo: Bool = true) {
        self.volumePath = volumePath
        self.installerPath = "\(volumePath)/\(appName).app"

        super.init(name: appName, path: self.installerPath)

        if addToRepo {
            self.addToRepo()
        }
    }

    init(isFakeInstaller: Bool = true, canInstallOnMachine: Bool, addToRepo: Bool = true) {
        if(isFakeInstaller) {
            self.volumePath = String.random(12)
            self.installerPath = String.random(12)

            super.init(name: "Fake Installer \(String.random(4, numericOnly: true))", path: String.random(4))

            self.isFakeInstaller = true
            self.fakeInstallerCanInstall = canInstallOnMachine

            if addToRepo {
                self.addToRepo()
            }
        } else {
            DDLogError("FakeInstaller initializer called with isFakeInstaller == false. FakeInstaller initializer should only be called with isFakeInstaller == true")
            fatalError("FakeInstaller initializer called with isFakeInstaller == false. FakeInstaller initializer should only be called with isFakeInstaller == true")
        }
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func addToRepo() {
        ItemRepository.shared.addToRepository(newItem: self)
    }

    static func == (lhs: Installer, rhs: Installer) -> Bool {
        return lhs.version == rhs.version
    }
}
