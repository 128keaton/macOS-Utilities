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

    private let libraryFolder = AppFolder.Library.url.appendingPathComponent("ER2").absoluteString.replacingOccurrences(of: "file://", with: "")
    private let propertyListName = "com.er2.applications"

    private (set) public var currentPreferences: Preferences? = nil

    public static var loaded = false

    init(useBundlePreferences: Bool = true) {
        if useBundlePreferences {
            if let bundlePreferences = loadPreferencesFromBundle() {
                self.currentPreferences = bundlePreferences
                NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
            }
        } else {
            if let libraryPreferences = loadPreferencesFromLibraryFolder() {
                self.currentPreferences = libraryPreferences
                NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
            }
        }
    }

    public func save(_ preferences: Preferences) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml

        let libraryPropertyListPath = "\(libraryFolder)/\(propertyListName).plist"
        let bundlePropertyListPath = Bundle.main.path(forResource: propertyListName, ofType: "plist")!

        do {
            let data = try encoder.encode(preferences)
            try data.write(to: URL(fileURLWithPath: libraryPropertyListPath))
            try data.write(to: URL(fileURLWithPath: bundlePropertyListPath))

            self.currentPreferences = preferences
            NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: true)

            DDLogInfo("Saved preferences to propertly list at path: \(libraryPropertyListPath)")
            DDLogInfo("Saved preferences to propertly list at path: \(bundlePropertyListPath)")
        } catch {
            DDLogError("Could not save preferences to propertly list at path: \(libraryPropertyListPath): \(error)")
            DDLogError("Could not save preferences to propertly list at path: \(bundlePropertyListPath): \(error)")
        }
    }

    public func updateApplications(_ applications: [String: [String: String]], shouldSave: Bool = true) {
        if var preferences = self.currentPreferences {
            preferences.applications = applications
            if shouldSave {
                save(preferences)
            } else {
                self.currentPreferences = preferences
            }
        }
    }

    // MARK Property List Retreival
    private func loadPreferences(_ path: String) -> Preferences? {
        if let xml = FileManager.default.contents(atPath: path) {
            if let parsedPreferences = try? PropertyListDecoder().decode(Preferences.self, from: xml) {
                return parsedPreferences
            }
        }
        return nil
    }

    public func loadPreferencesFromBundle() -> Preferences? {
        if let bundlePropertyListPath = Bundle.main.path(forResource: propertyListName, ofType: "plist") {
            return loadPreferences(bundlePropertyListPath)
        }
        return nil
    }

    public func loadPreferencesFromLibraryFolder() -> Preferences? {
        let libraryPropertyListPath = "\(libraryFolder)/\(propertyListName).plist"
        if FileManager.default.fileExists(atPath: libraryPropertyListPath) {
            return loadPreferences(libraryPropertyListPath)
        } else {
            if let bundlePropertyListPath = Bundle.main.path(forResource: propertyListName, ofType: "plist") {
                copyPlist(from: bundlePropertyListPath, to: libraryFolder)
                return loadPreferencesFromBundle()
            }
        }
        return nil
    }


    // MARK: Folder Creation
    private func createLibraryFolder() {
        try! FileManager.default.createDirectory(atPath: libraryFolder, withIntermediateDirectories: true, attributes: nil)
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

        if(currentPreferences != nil && currentPreferences?.loggingPreferences.loggingEnabled == true) {
            let logger = RMPaperTrailLogger.sharedInstance()!

            logger.debug = false

            guard let loggerHost = currentPreferences?.loggingPreferences.loggingURL else { return }
            guard let loggerPort = currentPreferences?.loggingPreferences.loggingPort else { return }

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
