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
    static let newDisk = Notification.Name("NSNewDisk")
    static let newInstaller = Notification.Name("NSNewInstaller")
    static let newVolume = Notification.Name("NSNewVolume")
    static let refreshRepository = Notification.Name("NSRefreshRepository")
    static let updatingApplications = Notification.Name("NSUpdatingApplications")
    static let hideApplications = Notification.Name("NSHideApplications")
    static let showApplications =  Notification.Name("NSShowApplications")

    private init() {
        DDLogInfo("ItemRepository initialized")

        DispatchQueue.main.async {
            self.reloadAllItems()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(ItemRepository.reloadAllItems), name: ItemRepository.refreshRepository, object: nil)
    }
    
    @objc public func reloadAllItems() {
        DiskUtility.shared.getAllDisks()
        ApplicationUtility.shared.getApplications()
        ApplicationUtility.shared.getUtilities()
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
        fakeItems.append(fakeInstaller)
    }

    public func updateDisk(_ disk: Disk) {
        self.items.removeAll { ($0 as? Disk) == disk }
        self.addToRepository(newDisk: disk)
    }

    public func getDisks() -> [Disk] {
        return (items.filter { type(of: $0) == Disk.self } as! [Disk]).sorted { $0.deviceIdentifier < $1.deviceIdentifier }
    }

    public func getVolumes() -> [Volume] {
        return (items.filter { type(of: $0) == Volume.self } as! [Volume]).sorted { $0.volumeName < $1.volumeName }
    }

    public func getInstallers() -> [Installer] {
        print(items.filter { type(of: $0) == Installer.self })
        return (items.filter { type(of: $0) == Installer.self } as! [Installer]).sorted { $0.comparibleVersionNumber < $1.comparibleVersionNumber }
    }

    public func getApplications() -> [Application] {
        return (items.filter { type(of: $0) == Application.self } as! [Application])
    }

    public func addToRepository(newDisk: Disk) {
        if(self.items.contains { ( $0 as? Disk) != nil && ( $0 as! Disk).id == newDisk.id } == false) {
            DDLogInfo("Adding disk '\(newDisk.deviceIdentifier)' to repo")
            self.items.append(newDisk)
            NotificationCenter.default.post(name: ItemRepository.newDisk, object: nil)
        }
    }

    public func addToRepository(newVolume: Volume) {
        if(self.items.contains { ( $0 as? Volume) != nil && ( $0 as! Volume).id == newVolume.id } == false) {
            DDLogInfo("Adding volume '\(newVolume.volumeName)' to repo")
            self.items.append(newVolume)
            NotificationCenter.default.post(name: ItemRepository.newVolume, object: nil)
        }
    }

    public func addToRepository(newInstaller: Installer) {
        if (self.items.contains { ( $0 as? Installer) != nil && ( $0 as! Installer).id == newInstaller.id } == false) {
            DDLogInfo("Adding installer '\(newInstaller.versionName)' to repo")
            self.items.append(newInstaller)
            NotificationCenter.default.post(name: ItemRepository.newInstaller, object: nil)
        }
    }

    public func addToRepository(newApplication: Application) {
        if (self.items.contains { ( $0 as? Application) != nil && ( $0 as! Application).id == newApplication.id } == false) {
            self.items.append(newApplication)

            if(newApplication.isUtility == false) {
                DDLogInfo("Adding application '\(newApplication.name)' to repo")
                NotificationCenter.default.post(name: ItemRepository.newApplication, object: nil)
            } else {
                DDLogInfo("Adding utility \(newApplication.name) to repo")
            }
        }
    }

    public func addToRepository(newApplications: [Application]) {
        self.items.append(contentsOf: newApplications)
        NotificationCenter.default.post(name: ItemRepository.newApplications, object: nil)
    }
}
