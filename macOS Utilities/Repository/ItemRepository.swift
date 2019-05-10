//
//  ItemRepository.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class ItemRepository {
    public static let shared = ItemRepository()
    private (set) public var items: [Any] = []

    private var fakeItems: [Any] = []

    static let newApplication = Notification.Name("NSNewApplication")
    static let newApplications = Notification.Name("NSNewApplications")

    static let newInstaller = Notification.Name("NSNewInstaller")
    static let removeInstaller = Notification.Name("NSRemoveInstaller")

    static let newUtility = Notification.Name("NSNewUtility")

    static let refreshRepository = Notification.Name("NSRefreshRepository")
    static let reloadApplications = Notification.Name("NSReloadApplications")

    private init() {
        DDLogInfo("ItemRepository initialized")

        DispatchQueue.main.async {
            self.reloadAllItems()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(ItemRepository.reloadAllItems), name: ItemRepository.refreshRepository, object: nil)
    }

    public func createFakeInstallers() {
        #if DEBUG
            addFakeInstaller()
            addFakeInstaller(canInstallOnMachine: true)
        #else
            DDLogError("Should only be called when debugging in Xcode. Thnx")
        #endif
    }

    @objc public func reloadAllItems() {
        DiskUtility.shared.getAllDisks()
        self.getUtilities()
    }

    private func reloadApplications() {
        if let preferences = PreferenceLoader.currentPreferences,
            let applications = preferences.mappedApplications {
            self.addToRepository(newApplications: applications)
        }
    }

    private func getUtilities() {
        do {
            try FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities").forEach {
                let utilityPath = $0
                let utilityName = utilityPath.split(separator: "/").last!.replacingOccurrences(of: ".app", with: "")
                if utilityName.first! != "." {
                    let newUtility = Utility(name: utilityName, path: utilityPath)
                    KBLogDebug("Adding utility '\(utilityName)' to repo.")
                    NotificationCenter.default.post(name: ItemRepository.newUtility, object: newUtility)
                    self.items.append(newUtility)
                }
            }
        } catch {
            DDLogError("Could not get utilities")
        }
    }

    public func has<T>(_ itemType: T.Type) -> Bool {
        return (items.filter { type(of: $0) == itemType }).count > 0
    }

    public var applications: [Application] {
        return (items.filter { type(of: $0) == Application.self } as! [Application])
    }

    public var allowedApplications: [Application] {
        return (items.filter { type(of: $0) == Application.self } as! [Application]).filter { $0.showInApplicationsWindow == true }
    }


    public var utilities: [Utility] {
        return (items.filter { type(of: $0) == Utility.self } as! [Utility])
    }

    public func getSelectedInstaller() -> Installer? {
        if let installer = (self.getInstallers().first { $0.isSelected == true }) {
            return installer
        }
        return nil
    }

    public func setSelectedInstaller(_ installer: Installer) {
        unsetAllSelectedInstallers()
        (items.first(where: { ($0 as? Installer) == installer }) as? Installer)?.isSelected = true
    }

    public func unsetAllSelectedInstallers() {
        (items.filter { type(of: $0) == Installer.self } as! [Installer]).forEach { $0.isSelected = false }
    }

    public func addFakeInstaller(canInstallOnMachine: Bool = false) {
        let fakeInstaller = Installer(isFakeInstaller: true, canInstallOnMachine: canInstallOnMachine)
        NotificationCenter.default.post(name: ItemRepository.newInstaller, object: fakeInstaller, userInfo: ["type": "add"])
        fakeItems.append(fakeInstaller)
    }

    public func getInstallers() -> [Installer] {
        return (items.filter { type(of: $0) == Installer.self } as! [Installer]).sorted { $0.comparibleVersionNumber < $1.comparibleVersionNumber }
    }
    
    public func removeInstaller(_ installerName: String) {
        DDLogVerbose("Looking for installer \(installerName) to remove from repository")

        if let foundInstaller = (items.first { type(of: $0) == Installer.self && ($0 as! Installer).versionName == installerName }) as? Installer {
            NotificationCenter.default.post(name: ItemRepository.removeInstaller, object: foundInstaller, userInfo: ["type": "remove"])
            items.removeAll { type(of: $0) == Installer.self && ($0 as! Installer) == foundInstaller }
        } else {
            DDLogVerbose("Could not find installer to remove from name: \(installerName)")
            DDLogVerbose("Current installers: \(self.getInstallers())")
        }
    }

    public func addToRepository(newInstaller: Installer) {
        if (self.items.contains { ($0 as? Installer) != nil && ($0 as! Installer).id == newInstaller.id } == false) {
            DDLogInfo("Adding installer '\(newInstaller.versionName)' to repo")
            self.items.append(newInstaller)

            NotificationCenter.default.post(name: ItemRepository.newInstaller, object: newInstaller, userInfo: ["type": "add"])
        }
    }

    public func addToRepository(newApplication: Application) {
        if (self.items.contains { ($0 as? Application) != nil && ($0 as! Application).id == newApplication.id } == false) {
            self.items.append(newApplication)

            DDLogInfo("Adding application '\(newApplication.name)' to repo")
            NotificationCenter.default.post(name: ItemRepository.newApplication, object: newApplication)
        }
    }

    public func addToRepository(newApplications: [Application], merge: Bool = false) {
        if !merge {
            self.items.removeAll { type(of: $0) == Application.self }
        }

        newApplications.forEach {
            DDLogInfo("Adding application '\($0.name)' to repo.")
        }

        self.items.append(contentsOf: newApplications)
        NotificationCenter.default.post(name: ItemRepository.newApplications, object: newApplications)
    }
}
