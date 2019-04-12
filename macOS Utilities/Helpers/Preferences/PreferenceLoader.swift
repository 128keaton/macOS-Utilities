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

    private (set) public var loadingFromBundle = true
    private (set) public var libraryPropertyListExists = false

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

    init(useBundlePreferences: Bool = false) {
        PreferenceLoader.sharedInstance = self

        constructLogger()
        if checkAndPerformInitialCopy() {
            libraryPropertyListExists = true

            if useBundlePreferences {
                if let bundlePreferences = loadPreferencesFromBundle() {
                    loadingFromBundle = true
                    PreferenceLoader.currentPreferences = bundlePreferences
                    PreferenceLoader.previousPreferences = bundlePreferences.copy() as? Preferences
                    constructRemoteLogger()
                    NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
                }
            } else {
                if let libraryPreferences = loadPreferencesFromLibraryFolder() {
                    loadingFromBundle = false
                    PreferenceLoader.currentPreferences = libraryPreferences
                    PreferenceLoader.previousPreferences = libraryPreferences.copy() as? Preferences
                    constructRemoteLogger()
                    NotificationCenter.default.post(name: PreferenceLoader.preferencesLoaded, object: nil)
                }
            }
        } else {
            DDLogError("Could not perform initial copy of property list.")
        }
    }

    private func checkAndPerformInitialCopy() -> Bool {
        if libraryPropertyListExists == false {
            if libraryFolderExists() {
                DDLogVerbose("Library folder exists at '\(PreferenceLoader.libraryFolder)'")
                if !verifyLibraryPreferencesExists() {
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
            } else {
                DDLogVerbose("Library folder does not exist at '\(PreferenceLoader.libraryFolder)'")
                if createLibraryFolder() {
                    return checkAndPerformInitialCopy()
                }
            }
            return false
        }

        return true
    }

    public func libraryFolderExists() -> Bool {
        var isDirectory: ObjCBool = true
        if FileManager.default.fileExists(atPath: PreferenceLoader.libraryFolder, isDirectory: &isDirectory) {
            return true
        }

        return false
    }

    public func verifyLibraryPreferencesExists() -> Bool {
        if FileManager.default.fileExists(atPath: libraryPropertyListPath) {
            libraryPropertyListExists = true
            return true
        }
        return false
    }

    public func save(_ preferences: Preferences, notify: Bool = true) {
        if PreferenceLoader.isDifferentFromRunning(),
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
                DDLogError("Could not save preferences to propertly list at path: \(bundlePropertyListPath): \(error)")
            }
        }
    }

    public static func saveRemoteConfigurationToDownloads(_ remoteConfiguration: RemoteConfigurationPreferences, fileName: String, createFolder: Bool = false, folderName: String = "") -> Bool {
        var dynamicFileURL: URL? = nil
        
        if createFolder == true {
            if let fileFolderContainingPath = self.createFolderInDownloadsForFile(folderName: folderName, fileName: fileName, fileExtension: "plist") {
                dynamicFileURL = fileFolderContainingPath
            }
        }else{
            dynamicFileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName).appendingPathExtension("plist")
        }

        do {
            let fileData = try PropertyListEncoder().encode(remoteConfiguration)
            
            if let fileURL = dynamicFileURL{
                let filePath = fileURL.absoluteString.replacingOccurrences(of: "file://", with: "")
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
        let folderPath = folderURL.absoluteString.replacingOccurrences(of: "file://", with: "")
        
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
        }else{
            dynamicFileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName).appendingPathExtension("plist")
        }

        do {
            let fileData = try PropertyListEncoder().encode(preferences)
            
            if let fileURL = dynamicFileURL{
                let filePath = fileURL.absoluteString.replacingOccurrences(of: "file://", with: "")
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

    public func loadPreferences(_ url: URL) -> Preferences? {
        do {
            let _data = try Data(contentsOf: url)
            let _preferences = try PropertyListDecoder().decode(Preferences.self, from: _data)
            return _preferences
        } catch let error {
            DDLogError("\(error)")
            print("Error parsing preferences: \(error)")
        }
        return nil
    }

    public func loadRemoteConfiguration(_ url: URL) -> RemoteConfigurationPreferences? {
        do {
            let _data = try Data(contentsOf: url)
            let _preferences = try PropertyListDecoder().decode(RemoteConfigurationPreferences.self, from: _data)
            return _preferences
        } catch let error {
            DDLogError("\(error)")
            print("Error parsing remote configuration: \(error)")
        }
        return nil
    }

    public func loadPreferencesFromBundle() -> Preferences? {
        if let bundlePropertyListPath = self.bundlePropertyListPath {
            return loadPreferences(bundlePropertyListPath)
        }
        return nil
    }

    public func loadPreferencesFromLibraryFolder() -> Preferences? {
        if libraryPropertyListExists {
            return loadPreferences(libraryPropertyListPath)
        }
        return nil
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

    // MARK: Logger
    public func constructLogger() {
        let fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7

        if (DDLog.allLoggers.filter { type(of: $0) == DDFileLogger.self }).count == 0 {
            DDLog.add(fileLogger)
            DDLog.add(ErrorAlertLogger())
            DDLog.add(DDOSLogger.sharedInstance)

            DDLogInfo(NSApplication.shared.getVerboseName())
            DDLogInfo("\n")
            DDLogInfo("\n---------------------------LOGGER INITIALIZED---------------------------")
            DDLogInfo("\n")
            return
        }

        DDLogVerbose("Logger already initialized, not reinitializing.")
    }

    public func constructRemoteLogger() {
        if(PreferenceLoader.currentPreferences != nil && PreferenceLoader.currentPreferences?.loggingPreferences?.loggingEnabled == true) {
            let logger = RMPaperTrailLogger.sharedInstance()!

            logger.debug = false

            guard let loggerHost = PreferenceLoader.currentPreferences?.loggingPreferences?.loggingURL else { return }
            guard let loggerPort = PreferenceLoader.currentPreferences?.loggingPreferences?.loggingPort else { return }

            logger.host = loggerHost
            logger.port = loggerPort
            logger.machineName = Host.current().localizedName != nil ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__\(getSystemUUID() ?? ""))") : String("\(Sysctl.model)__(\(getSystemUUID() ?? ""))")

            #if DEBUG
                logger.machineName = logger.machineName! + "__DEBUG__"
            #endif

            logger.programName = NSApplication.shared.getVerboseName()
            DDLog.add(logger, with: .debug)
            DDLogInfo("NOTICE: Remote logging enabled")

        } else {
            if PreferenceLoader.currentPreferences == nil {
                DDLogInfo("NOTICE: Remote logging disabled: preferences are nil.")
            } else if let currentPreferences = PreferenceLoader.currentPreferences,
                let validLoggingPreferences = currentPreferences.loggingPreferences {
                if (validLoggingPreferences.loggingEnabled == false) {
                    DDLogInfo("NOTICE: Remote logging disabled: preferences are set to disable remote logging (remoteLoggingEnabled = \(validLoggingPreferences.loggingEnabled)).")
                } else if (validLoggingPreferences.loggingPort == 0) {
                    DDLogInfo("NOTICE: Remote logging disabled: logging port set to zero (loggingPort = \(validLoggingPreferences.loggingPort)).")
                } else if (validLoggingPreferences.loggingURL == "") {
                    DDLogInfo("NOTICE: Remote logging disabled: logging url set to empty (loggingURL = \(validLoggingPreferences.loggingURL)).")
                }
            } else {
                DDLogInfo("Remote logging disabled: loggingPreferences are nil.")
            }
        }
    }
}
