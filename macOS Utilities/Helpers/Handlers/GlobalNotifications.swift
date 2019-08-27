//
//  GlobalNotifications.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class GlobalNotifications {
    public static let quitNow = Notification.Name("NSQuitApplicationNow")
    
    // MARK: Disk Notifications
    public static let bootDiskAvailable = Notification.Name("NSBootDiskAvailable")
    public static let diskImageMounted = Notification.Name("NSDiskImageMounted")
    public static let diskImageUnmounted = Notification.Name("NSDiskImageUnmounted")

    public static let newDisks = Notification.Name("NSNewDisks")
    public static let newShares = Notification.Name("NSNewShares")

    
    // MARK: Item Repository Notifications
    static let newApplication = Notification.Name("NSNewApplication")
    static let newApplications = Notification.Name("NSNewApplications")
    
    static let newInstaller = Notification.Name("NSNewInstaller")
    static let removeInstaller = Notification.Name("NSRemoveInstaller")
    
    static let newUtility = Notification.Name("NSNewUtility")
    
    static let refreshRepository = Notification.Name("NSRefreshRepository")
    static let reloadApplications = Notification.Name("NSReloadApplications")
    static let openApplication = Notification.Name("NSOpenApplicationFromRepository")
    
    // MARK: Preferences Notifications
    static let preferencesLoaded = Notification.Name(rawValue: "NSPreferencesLoaded")
    static let preferencesUpdated = Notification.Name(rawValue: "NSPreferencesUpdated")
}
