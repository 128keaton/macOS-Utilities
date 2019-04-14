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

    public static let libraryFolder = "\(AppFolder.Library.Application_Support.url.path)/ER2/"
    public static let bundle = Bundle.main
    public static let propertyListName = "com.er2.applications"

    public let libraryPropertyListPath = "\(PreferenceLoader.libraryFolder)\(PreferenceLoader.propertyListName).plist"
    public let bundlePropertyListPath = Bundle.main.path(forResource: PreferenceLoader.propertyListName, ofType: "plist")

    private (set) public static var currentPreferences: Preferences? = nil

    private (set) public static var sharedInstance: PreferenceLoader? = nil
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

    init() {
        PreferenceLoader.sharedInstance = self

        LoggerSetup.constructLogger()
        if checkAndPerformInitialCopy() {
            if let preferences = parsePreferences(libraryPropertyListPath, forceSave: true) {
                PreferenceLoader.currentPreferences = preferences
                PreferenceLoader.previousPreferences = preferences.copy() as? Preferences
                if let loggingPreferences = preferences.loggingPreferences {
                    LoggerSetup.constructRemoteLogger(loggingPreferences: loggingPreferences)
                }
                NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
            }
        }
    }

    private func checkAndPerformInitialCopy() -> Bool {
        if createLibraryFolder() {
            DDLogVerbose("Library folder exists at '\(PreferenceLoader.libraryFolder)'")
            if libraryPropertyListPath.fileURL.filestatus != .isFile {
                DDLogVerbose("Property list does not exist at '\(PreferenceLoader.libraryFolder)\(PreferenceLoader.propertyListName).plist'")
                if let bundlePropertyListPath = Bundle.main.path(forResource: PreferenceLoader.propertyListName, ofType: "plist") {
                    DDLogInfo("Copying property list from bundle")
                    let copyStatus = copyPlist(from: bundlePropertyListPath, to: "\(PreferenceLoader.libraryFolder)/\(PreferenceLoader.propertyListName).plist")
                    if copyStatus.0 == false {
                        DDLogError("Could not copy property list from '\(bundlePropertyListPath)' to '\(PreferenceLoader.libraryFolder)': \(copyStatus.1 ?? "No error description")")
                    } else {
                        DDLogVerbose("Copied property list from '\(bundlePropertyListPath)' to '\(PreferenceLoader.libraryFolder)' successfully")
                        return true
                    }
                } else {
                    DDLogVerbose("Property list does not exist at '\(Bundle.main)/\(PreferenceLoader.propertyListName).plist'")
                    DDLogError("Default property list does not exist in bundle.")
                }
            } else {
                DDLogVerbose("Property list exists at '\(PreferenceLoader.libraryFolder)\(PreferenceLoader.propertyListName).plist'")
                return true
            }
        }
        return false
    }

    public func save(_ preferences: Preferences, notify: Bool = true) {
        if PreferenceLoader.isDifferentFromRunning(preferences),
            let bundlePropertyListPath = self.bundlePropertyListPath {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml

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
                DDLogVerbose("Could not save preferences to propertly list at path: \(bundlePropertyListPath): \(error)")
            }
        }
    }

    public static func saveRemoteConfigurationToDownloads(_ remoteConfiguration: RemoteConfigurationPreferences, fileName: String, createFolder: Bool = false, folderName: String = "") -> Bool {
        var dynamicFileURL: URL? = nil

        if createFolder == true {
            if let fileFolderContainingPath = self.createFolderInDownloadsForFile(folderName: folderName, fileName: fileName, fileExtension: "plist") {
                dynamicFileURL = fileFolderContainingPath
            }
        } else {
            dynamicFileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName).appendingPathExtension("plist")
        }

        do {
            let fileData = try PropertyListEncoder().encode(remoteConfiguration)

            if let fileURL = dynamicFileURL {
                let filePath = fileURL.absolutePath
                return FileManager.default.createFile(atPath: filePath, contents: fileData, attributes: nil)
            }

            return false
        } catch {
            DDLogError(error.localizedDescription)
            return false
        }
    }

    private static func createFolderInDownloadsForFile(folderName: String, fileName: String, fileExtension: String) -> URL? {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let folderURL = downloadsURL.appendingPathComponent(folderName, isDirectory: true)
        let folderPath = folderURL.absolutePath

        var isDirectory: ObjCBool = true
        if FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory) {
            return folderURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DDLogError(error.localizedDescription)
            return nil
        }

        return folderURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }

    public static func savePreferencesToDownloads(_ preferences: Preferences, fileName: String, createFolder: Bool = false, folderName: String = "") -> Bool {
        var dynamicFileURL: URL? = nil

        if createFolder == true {
            if let fileFolderContainingPath = self.createFolderInDownloadsForFile(folderName: folderName, fileName: fileName, fileExtension: "plist") {
                dynamicFileURL = fileFolderContainingPath
            }
        } else {
            dynamicFileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName).appendingPathExtension("plist")
        }

        do {
            let fileData = try PropertyListEncoder().encode(preferences)

            if let fileURL = dynamicFileURL {
                let filePath = fileURL.absolutePath
                return FileManager.default.createFile(atPath: filePath, contents: fileData, attributes: nil)
            }

            return false
        } catch {
            DDLogError(error.localizedDescription)
            return false
        }
    }

    public static func save(_ preferences: Preferences, notify: Bool = true) {
        if let weakSelf = self.sharedInstance,
            let bundlePropertyListPath = weakSelf.bundlePropertyListPath {
            let libraryPropertyListPath = weakSelf.libraryPropertyListPath

            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml

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
    }

    public func getSaveDirectoryPath(relativeToUser: Bool = true) -> String {
        if !relativeToUser {
            return libraryPropertyListPath
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.absolutePath

        return libraryPropertyListPath.replacingOccurrences(of: homeDirectory, with: "~/")
    }

    // MARK Property List Retreival
    public func parsePreferences(_ at: String, forceSave: Bool = false) -> Preferences? {
        if let xml = FileManager.default.contents(atPath: at) {
            do {
                let preferences = try PropertyListDecoder().decode(Preferences.self, from: xml)
                return preferences
            } catch let error {
                let loadLegacyStatus = parseLegacyPreferences(atPath: at, atURL: nil)
                if loadLegacyStatus.0 == true {
                    if let convertedPreferences = loadLegacyStatus.1,
                        forceSave == true {
                        save(convertedPreferences)
                    }
                    return loadLegacyStatus.1
                } else if loadLegacyStatus.0 == false {
                    DDLogError("Could not load preferences. \(error). \n Attempted to parse as a legacy property list, but that also failed: \(loadLegacyStatus.2!)")
                }
            }
        }
        return nil
    }

    public func parsePreferences(_ at: URL, forceSave: Bool = false) -> Preferences? {
        do {
            let _data = try Data(contentsOf: at)
            let _preferences = try PropertyListDecoder().decode(Preferences.self, from: _data)
            return _preferences
        } catch let error {
            let loadLegacyStatus = parseLegacyPreferences(atPath: nil, atURL: at)
            if loadLegacyStatus.0 == true {
                if let convertedPreferences = loadLegacyStatus.1,
                    forceSave == true {
                    save(convertedPreferences)
                }
                return loadLegacyStatus.1
            } else if loadLegacyStatus.0 == false {
                DDLogError("Could not load preferences. \(error). \n Attempted to parse as a legacy property list, but that also failed: \(loadLegacyStatus.2!)")
            }
        }

        return nil
    }

    public func parseLegacyPreferences(atPath: String?, atURL: URL?) -> (Bool, Preferences?, Error?) {
        if let at = atPath {
            if let xml = FileManager.default.contents(atPath: at) {
                do {
                    let legacyPreferences = try PropertyListDecoder().decode(LegacyPreferences.self, from: xml)
                    DDLogInfo("Successfully converted legacy preferences from \(at)")
                    return (true, legacyPreferences.update(), nil)
                } catch let error {
                    return (false, nil, error)
                }
            }
            return (false, nil, nil)
        } else if let at = atURL {
            do {
                let xml = try Data(contentsOf: at)
                let legacyPreferences = try PropertyListDecoder().decode(LegacyPreferences.self, from: xml)
                DDLogInfo("Successfully converted legacy preferences from \(at)")
                return (true, legacyPreferences.update(), nil)
            } catch let error {
                return (false, nil, error)
            }
        }

        return (false, nil, nil)
    }

    public func fetchRemoteConfiguration(_ url: URL) -> RemoteConfigurationPreferences? {
        do {
            let _data = try Data(contentsOf: url)
            let _preferences = try PropertyListDecoder().decode(RemoteConfigurationPreferences.self, from: _data)
            return _preferences
        } catch let error {
            DDLogError("Error parsing remote configuration: \(error)")
        }
        return nil
    }

    public static func loadPreferences(_ from: String) -> Bool {
        if let sharedInstance = self.sharedInstance {
            if let newPreferences = sharedInstance.parsePreferences(from) {
                sharedInstance.save(newPreferences, notify: true)
                return true
            }
        }
        return false
    }

    public static func loadPreferences(_ from: URL) -> Bool {
        if let sharedInstance = self.sharedInstance {
            if let newPreferences = sharedInstance.parsePreferences(from) {
                sharedInstance.save(newPreferences, notify: true)
                return true
            }
        }
        return false
    }

    // MARK: Folder Creation
    private func createLibraryFolder() -> Bool {
        DDLogVerbose("Creating folder at path '\(PreferenceLoader.libraryFolder)'")
        do {
            try FileManager.default.createDirectory(atPath: PreferenceLoader.libraryFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DDLogError("Unable to make folder at path '\(PreferenceLoader.libraryFolder)': \(error.localizedDescription)")
            return false
        }

        return true
    }

    private func copyPlist(from: String, to: String) -> (Bool, String?) {
        do {
            try FileManager.default.copyItem(atPath: from, toPath: to)
        } catch {
            return (false, error.localizedDescription)
        }

        return (true, nil)
    }
}
