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
    public static let libraryFolder = "\(AppFolder.Library.Application_Support.url.path)/macOS Utilities/"
    public static let bundle = Bundle.main
    public static let propertyListName = "com.er2.applications"

    public let libraryPropertyListPath = "\(PreferenceLoader.libraryFolder)\(PreferenceLoader.propertyListName).plist"
    public let bundlePropertyListPath = Bundle.main.path(forResource: PreferenceLoader.propertyListName, ofType: "plist")

    private (set) public static var currentPreferences: Preferences? = nil
    private (set) public static var sharedInstance: PreferenceLoader? = nil

    private static var previousPreferences: Preferences? = nil

    // MARK: Initializers
    public static func setup() {
        LoggerManager.constructLogger()
        self.sharedInstance = PreferenceLoader()
    }

    private init() {
        if checkAndPerformInitialCopy() {
            if let preferences = parsePreferences(libraryPropertyListPath, forceSave: true) {
                PreferenceLoader.currentPreferences = preferences
                PreferenceLoader.previousPreferences = preferences.copy() as? Preferences
                self.setupOtherServices()
                NotificationCenter.default.post(name: GlobalNotifications.preferencesLoaded, object: nil)
            }
        }
    }

    // MARK: Public functions
    /// Save preferences to property list in configured folders. Set notify to 'true' to notify listeners of a preference change
    public func save(_ preferences: Preferences, notify: Bool = true) {
        if PreferenceLoader.isDifferentFromRunning(preferences),
            let bundlePropertyListPath = self.bundlePropertyListPath {
            let temporaryPath = "/var/tmp/\(PreferenceLoader.propertyListName).plist"
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml

            let writeToBundle = FileManager.default.isWritableFile(atPath: bundlePropertyListPath)
            let writeToLibrary = FileManager.default.isWritableFile(atPath: libraryPropertyListPath)

            DDLogVerbose("Can save preferences in bundle? \(writeToBundle)")

            do {
                let data = try encoder.encode(preferences)
                if writeToBundle {
                    let bundlePreferences = (preferences.copy() as! Preferences)
                    if let applications = bundlePreferences.mappedApplications {
                        applications.forEach { $0.showInApplicationsWindow = true }
                        bundlePreferences.mappedApplications = applications
                    }

                    let bundleData = try encoder.encode(bundlePreferences)
                    try bundleData.write(to: URL(fileURLWithPath: bundlePropertyListPath))
                    DDLogVerbose("Saved preferences to propertly list at path: \(bundlePropertyListPath)")
                }


                if writeToLibrary {
                    try data.write(to: URL(fileURLWithPath: libraryPropertyListPath))
                    DDLogVerbose("Saved preferences to propertly list at path: \(libraryPropertyListPath)")
                } else if FileManager.default.isWritableFile(atPath: temporaryPath) {
                    DDLogVerbose("Writing to temporary preferences path")
                    try data.write(to: URL(fileURLWithPath: temporaryPath))
                    DDLogVerbose("Saved preferences to propertly list at path: \(temporaryPath)")
                } else {
                    DDLogError("Could not find a suitable place to save the preferences")
                }

                if notify {
                    PreferenceLoader.currentPreferences = preferences
                    NotificationCenter.default.post(name: GlobalNotifications.preferencesLoaded, object: true)
                } else {
                    NotificationCenter.default.post(name: GlobalNotifications.preferencesUpdated, object: preferences)
                }
            } catch {
                DDLogError("Could not save preferences: \(error)")
            }
        }
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

                if var applications = _preferences.mappedApplications {
                    applications.removeAll { $0.applicationPath == "" || !$0.applicationPath.contains(".app") }
                    _preferences.mappedApplications = applications
                }

                return _preferences
            } catch let error {
                let loadLegacyStatus = parseLegacyPreferences(atPath: nil, atURL: at)
                if loadLegacyStatus.0 == true {
                    if let convertedPreferences = loadLegacyStatus.1,
                        forceSave == true {
                        if var applications = convertedPreferences.mappedApplications {
                            applications.removeAll { $0.applicationPath == "" || !$0.applicationPath.contains(".app") }
                            convertedPreferences.mappedApplications = applications
                        }
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


        // MARK: Getters
        public func getSaveDirectoryPath(relativeToUser: Bool = true) -> String {
            if !relativeToUser {
                return libraryPropertyListPath
            }

            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.absolutePath
            return libraryPropertyListPath.replacingOccurrences(of: homeDirectory, with: "~/")
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

        private func setupOtherServices() {
            if let preferences = PreferenceLoader.currentPreferences {
                if let loggingPreferences = preferences.loggingPreferences {
                    LoggerManager.constructRemoteLogger(loggingPreferences: loggingPreferences)
                }

                if let applications = preferences.mappedApplications {
                    ItemRepository.shared.addToRepository(newItems: applications)
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
                        let copyStatus = FileManager.default.copyFile(from: bundlePropertyListPath, to: "\(PreferenceLoader.libraryFolder)/\(PreferenceLoader.propertyListName).plist")
                        if copyStatus.0 == false {
                            DDLogError("Could not copy property list from '\(bundlePropertyListPath)' to '\(PreferenceLoader.libraryFolder)': \(copyStatus.1?.localizedDescription ?? "No error description")")
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

        // MARK: Static functions
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
                if let fileFolderContainingPath = self.createFolderInDownloadsForFile(folderName: folderName, fileName: fileName, fileExtension: "utilconf") {
                    dynamicFileURL = fileFolderContainingPath
                }
            } else {
                dynamicFileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName).appendingPathExtension("utilconf")
            }

            do {
                let fileData = try PropertyListEncoder().encode(preferences)

                if let fileURL = dynamicFileURL {
                    let filePath = fileURL.absolutePath.dashedFileName
                    return FileManager.default.createFile(atPath: filePath, contents: fileData, attributes: nil)
                }

                return false
            } catch {
                DDLogError(error.localizedDescription)
                return false
            }
        }

        public static func save(_ preferences: Preferences, notify: Bool = true) {
            if let unownedSelf = self.sharedInstance {
                unownedSelf.save(preferences, notify: notify)
            }
        }

        public static func loadPreferences(_ from: String, updatingRunning: Bool = false) -> Bool {
            if let sharedInstance = self.sharedInstance {
                if let newPreferences = sharedInstance.parsePreferences(from) {
                    sharedInstance.save(newPreferences, notify: !updatingRunning)
                    PreferenceLoader.currentPreferences = newPreferences
                    return true
                }
            }
            return false
        }

        public static func loadPreferences(_ from: URL, updatingRunning: Bool = false) -> Bool {
            if let sharedInstance = self.sharedInstance {
                if let newPreferences = sharedInstance.parsePreferences(from) {
                    sharedInstance.save(newPreferences, notify: !updatingRunning)
                    PreferenceLoader.currentPreferences = newPreferences
                    return true
                }
            }
            return false
        }

        public static func isDifferentFromRunning(_ preferences: Preferences? = nil) -> Bool {
            guard let runningPreferences = previousPreferences else { return true }

            var validPreferences: Preferences? = preferences

            if validPreferences == nil {
                validPreferences = PreferenceLoader.currentPreferences
            }

            guard let _preferences = validPreferences else { return true }

            return _preferences == runningPreferences
        }
    }
