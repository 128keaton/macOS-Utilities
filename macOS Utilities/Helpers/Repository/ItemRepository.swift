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
    private (set) public var items: [RepositoryItem] = []

    private var fakeItems: [Any] = []

    public var applications: [Application] {
        return (items.filter { type(of: $0) == Application.self } as! [Application])
    }

    public var allowedApplications: [Application] {
        return (items.filter { type(of: $0) == Application.self } as! [Application]).filter { $0.showInApplicationsWindow == true }
    }

    public var utilities: [Utility] {
        return (items.filter { type(of: $0) == Utility.self } as! [Utility])
    }

    public var installers: [Installer] {
        return (items.filter { type(of: $0) == Installer.self } as! [Installer]).sorted { $0.sortNumber!.compare($1.sortNumber!) == .orderedAscending && $0.isFakeInstaller == false }
    }

    public var selectedInstaller: Installer? {
        if let installer = (self.installers.first { $0.isSelected == true }) {
            return installer
        }
        return nil
    }

    private init() {
        DDLogInfo("ItemRepository initialized")

        DispatchQueue.main.async {
            self.reloadAllItems()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(ItemRepository.reloadAllItems), name: GlobalNotifications.refreshRepository, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ItemRepository.openApplication(notification:)), name: GlobalNotifications.openApplication, object: nil)
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
        self.scanForMountedInstallers()
        Utility.getFromUtilitiesFolder()
    }

    public func openApplication(appName: String) {
        if let foundItem = (self.items.first { $0.searchableEntityName == appName }) {
            if let foundUtility = foundItem as? Utility,
                foundUtility.open() {
                DDLogVerbose("Launched utility \(foundUtility)")
            } else if let foundApplication = foundItem as? Application,
                foundApplication.open() {
                DDLogVerbose("Launched application \(foundApplication)")
            } else {
                DDLogError("Could not launch application \(foundItem)")
            }
        } else {
            DDLogError("Could not launch application \(appName). Application was not found in ItemRepository.")
        }
    }

    @objc public func openApplication(notification: Notification? = nil) {
        if let openNotification = notification,
            let notificationOpenName = openNotification.object as? String {
            openApplication(appName: notificationOpenName)
        } else {
            DDLogError("Could launch application. No name was specified")
        }
    }

    public func openApplication(_ application: Application) {
        openApplication(appName: application.name)
    }

    private func reloadApplications() {
        if let preferences = PreferenceLoader.currentPreferences,
            let applications = preferences.mappedApplications {
            self.addToRepository(newItems: applications)
        }
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
        NotificationCenter.default.post(name: GlobalNotifications.newInstaller, object: fakeInstaller, userInfo: ["type": "add"])
        fakeItems.append(fakeInstaller)
    }

    public func addToRepository<T>(newItems: [T], merge: Bool = false) {
        if var newItemsOfType = newItems as? [RepositoryItem] {
            if merge {
                newItemsOfType.removeAll { self.items.contains($0) }
            }

            newItemsOfType.forEach {
                addToRepository(newItem: $0)
            }

            if let anItem = newItemsOfType.first {
                if type(of: anItem) == Application.self {
                    NotificationCenter.default.post(name: GlobalNotifications.newApplications, object: newItemsOfType as! [Application])
                }
            }
        }
    }

    public func has<T>(_ itemType: T.Type) -> Bool {
        return (items.filter { type(of: $0) == itemType }).count > 0
    }

    public func scanForMountedInstallers() {
        do {
            let mountedVolumes = try FileManager.default.contentsOfDirectory(atPath: "/Volumes")
            mountedVolumes.filter { $0.contains("Install macOS") || $0.contains("Install Mac OS X") }.forEach {
                let newInstaller = Installer(volumePath: "/Volumes/\($0)", appName: $0)
                self.addToRepository(newItem: newInstaller)
            }
        } catch {
            DDLogError("Could not scan for mounted installers: \(error)")
        }
    }

    public func addToRepository<T>(newItem: T) {
        if let newItemOfType = newItem as? RepositoryItem,
            (self.items.contains { $0.id == newItemOfType.id } == false) {

            DDLogInfo("Adding \(NSStringFromClass(type(of: newItemOfType)).replacingOccurrences(of: "macOS_Utilities.", with: "")) '\(newItemOfType.searchableEntityName)' to repo")

            if type(of: newItemOfType) == Application.self {
                self.items.append(newItemOfType as! Application)
                NotificationCenter.default.post(name: GlobalNotifications.newApplication, object: newItemOfType as! Application)
            } else if type(of: newItemOfType) == Utility.self {
                self.items.append(newItemOfType as! Utility)
                NotificationCenter.default.post(name: GlobalNotifications.newUtility, object: newItemOfType as! Utility)
            } else if type(of: newItemOfType) == Installer.self {
                self.items.append(newItemOfType as! Installer)
                NotificationCenter.default.post(name: GlobalNotifications.newInstaller, object: (newItemOfType as! Installer), userInfo: ["type": "add"])
            }
        }
    }

    public func removeFromRepository<T>(itemToRemove: T) {
        if let itemToRemoveOfType = itemToRemove as? RepositoryItem,
            (self.items.contains { $0.id == itemToRemoveOfType.id } == true) {

            DDLogInfo("Removing \(NSStringFromClass(type(of: itemToRemoveOfType))) '\(itemToRemoveOfType.searchableEntityName)' from repo")

            if type(of: itemToRemoveOfType) == Application.self {
                self.items.removeAll { $0 == (itemToRemoveOfType as! Application) }
                NotificationCenter.default.post(name: GlobalNotifications.reloadApplications, object: nil)
            } else if type(of: itemToRemoveOfType) == Utility.self {
                self.items.removeAll { $0 == (itemToRemoveOfType as! Utility) }
                NotificationCenter.default.post(name: GlobalNotifications.reloadApplications, object: nil)
            } else if type(of: itemToRemoveOfType) == Installer.self {
                self.items.removeAll { $0 == (itemToRemoveOfType as! Installer) }
                NotificationCenter.default.post(name: GlobalNotifications.removeInstaller, object: (itemToRemoveOfType as! Installer), userInfo: ["type": "remove"])
            }
        }
    }
}
