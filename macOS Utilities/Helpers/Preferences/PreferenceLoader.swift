//
//  PreferenceLoader.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppFolder
import PaperTrailLumberjack

class PreferenceLoader {
    static let preferencesLoaded = NSNotification.Name(rawValue: "NSPreferencesLoaded")
    static let preferencesUpdated = NSNotification.Name(rawValue: "NSPreferencesUpdated")

    private static let libraryFolder = AppFolder.Library.url.appendingPathComponent("ER2").absoluteString.replacingOccurrences(of: "file://", with: "")
    private static let propertyListName = "com.er2.applications"

    private (set) public static var currentPreferences: Preferences? = nil

    public static var loaded = false

    private static var previousPreferences: Preferences? = nil


    static func isDifferentFromRunning(_ preferences: Preferences? = nil) -> Bool {
        guard let runningPreferences = previousPreferences else { return true }

        var validPreferences: Preferences? = preferences

        if validPreferences == nil {
            validPreferences = PreferenceLoader.currentPreferences
        }

        guard let _preferences = validPreferences else { return true }

        if(runningPreferences.installerServerPreferences != _preferences.installerServerPreferences) {
            return true
        }

        if(runningPreferences.loggingPreferences != _preferences.loggingPreferences) {
            return true
        }

        if(runningPreferences.useDeviceIdentifierAPI != _preferences.useDeviceIdentifierAPI) {
            return true
        }

        if(runningPreferences.helpEmailAddress != _preferences.helpEmailAddress) {
            return true
        }

        return false
    }

    init(useBundlePreferences: Bool = true) {
        if useBundlePreferences {
            if let bundlePreferences = loadPreferencesFromBundle() {
                PreferenceLoader.currentPreferences = bundlePreferences
                PreferenceLoader.previousPreferences = bundlePreferences.copy() as? Preferences
                NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
            }
        } else {
            if let libraryPreferences = loadPreferencesFromLibraryFolder() {
                PreferenceLoader.currentPreferences = libraryPreferences
                PreferenceLoader.previousPreferences = libraryPreferences.copy() as? Preferences
                NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
            }
        }
    }

    public func save(_ preferences: Preferences, notify: Bool = true) {
        if PreferenceLoader.isDifferentFromRunning() {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml

            let libraryPropertyListPath = "\(PreferenceLoader.libraryFolder)/\(PreferenceLoader.propertyListName).plist"
            let bundlePropertyListPath = Bundle.main.path(forResource: PreferenceLoader.propertyListName, ofType: "plist")!

            do {
                let data = try encoder.encode(preferences)
                try data.write(to: URL(fileURLWithPath: libraryPropertyListPath))

                #if !DEBUG
                    try data.write(to: URL(fileURLWithPath: bundlePropertyListPath))
                #endif

                if notify {
                    PreferenceLoader.previousPreferences = preferences
                    PreferenceLoader.currentPreferences = preferences.copy() as? Preferences
                    NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: true)
                }

                DDLogInfo("Saved preferences to propertly list at path: \(libraryPropertyListPath)")
                DDLogInfo("Saved preferences to propertly list at path: \(bundlePropertyListPath)")
            } catch {
                DDLogError("Could not save preferences to propertly list at path: \(libraryPropertyListPath): \(error)")
                DDLogError("Could not save preferences to propertly list at path: \(bundlePropertyListPath): \(error)")
            }
        }
    }

    public static func save(_ preferences: Preferences, notify: Bool = true) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml

        let libraryPropertyListPath = "\(libraryFolder)/\(propertyListName).plist"
        let bundlePropertyListPath = Bundle.main.path(forResource: propertyListName, ofType: "plist")!

        do {
            let data = try encoder.encode(preferences)
            try data.write(to: URL(fileURLWithPath: libraryPropertyListPath))

            #if !DEBUG
                try data.write(to: URL(fileURLWithPath: bundlePropertyListPath))
            #endif

            if notify {
                PreferenceLoader.currentPreferences = preferences
                NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: true)
            }

            DDLogInfo("Saved preferences to propertly list at path: \(libraryPropertyListPath)")
            DDLogInfo("Saved preferences to propertly list at path: \(bundlePropertyListPath)")
        } catch {
            DDLogError("Could not save preferences to propertly list at path: \(libraryPropertyListPath): \(error)")
            DDLogError("Could not save preferences to propertly list at path: \(bundlePropertyListPath): \(error)")
        }
    }

    // MARK Property List Retreival
    private func loadPreferences(_ path: String) -> Preferences? {
        if let xml = FileManager.default.contents(atPath: path) {
            do {
                let preferences = try PropertyListDecoder().decode(Preferences.self, from: xml)
                return preferences
            } catch let error {
                DDLogError("\(error)")
                print("Error parsing preferences: \(error)")
            }
        }
        return nil
    }

    public func loadPreferencesFromBundle() -> Preferences? {
        if let bundlePropertyListPath = Bundle.main.path(forResource: PreferenceLoader.propertyListName, ofType: "plist") {
            return loadPreferences(bundlePropertyListPath)
        }
        return nil
    }

    public func loadPreferencesFromLibraryFolder() -> Preferences? {
        let libraryPropertyListPath = "\(PreferenceLoader.libraryFolder)/\(PreferenceLoader.propertyListName).plist"
        if FileManager.default.fileExists(atPath: libraryPropertyListPath) {
            return loadPreferences(libraryPropertyListPath)
        } else {
            if let bundlePropertyListPath = Bundle.main.path(forResource: PreferenceLoader.propertyListName, ofType: "plist") {
                copyPlist(from: bundlePropertyListPath, to: PreferenceLoader.libraryFolder)
                return loadPreferencesFromBundle()
            }
        }
        return nil
    }


    // MARK: Folder Creation
    private func createLibraryFolder() {
        try! FileManager.default.createDirectory(atPath: PreferenceLoader.libraryFolder, withIntermediateDirectories: true, attributes: nil)
    }

    private func copyPlist(from: String, to: String) {
        createLibraryFolder()
        try! FileManager.default.copyItem(atPath: from, toPath: to)
    }

    // MARK: Logger
    public func constructLogger() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        let fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7

        DDLog.add(fileLogger)
        DDLog.add(ErrorAlertLogger())
        DDLog.add(DDOSLogger.sharedInstance)

        if(PreferenceLoader.currentPreferences != nil && PreferenceLoader.currentPreferences?.loggingPreferences.loggingEnabled == true) {
            let logger = RMPaperTrailLogger.sharedInstance()!

            logger.debug = false

            guard let loggerHost = PreferenceLoader.currentPreferences?.loggingPreferences.loggingURL else { return }
            guard let loggerPort = PreferenceLoader.currentPreferences?.loggingPreferences.loggingPort else { return }

            logger.host = loggerHost
            logger.port = loggerPort

            print(logger.port)
            print(logger.host)

            logger.machineName = Host.current().localizedName != nil ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__\(getSystemUUID() ?? ""))") : String("\(Sysctl.model)__(\(getSystemUUID() ?? ""))")

            #if DEBUG
                logger.machineName = logger.machineName! + "__DEBUG__"
            #endif

            logger.programName = "macOS_Utilities-\(version)-\(build)"
            DDLog.add(logger, with: .debug)
            DDLogInfo("Remote logging enabled")
        } else {
            DDLogInfo("Remote logging disabled")
        }

        DDLogInfo("macOS_Utilities-\(version)-\(build)")
        DDLogInfo("\n")
        DDLogInfo("\n---------------------------LOGGER INITIALIZED---------------------------")
        DDLogInfo("\n")
    }
}
