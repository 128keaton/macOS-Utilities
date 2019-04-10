//
//  Preferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/18/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppFolder
import PaperTrailLumberjack

class Preferences {
    private let libraryFolder = AppFolder.Library
    private var serverInfo: [String]? = nil
    private var loggingInfo: [Any]? = nil
    private var sections: [String: [String: String]] = [:]

    private var hostDiskPath = "/Library/Server/Web/Data/Sites/Default/Installers"
    private var hostDiskServer = "172.16.5.5"

    private var logHost = ""
    private var logPort = 1234

    private (set) public var remoteLoggingEnabled = false
    static let shared = Preferences()

    private init() {
        self.constructLogger()
        createLibraryFolder()
    }

    fileprivate func createLibraryFolder() {
        let url = libraryFolder.url
        let fileManager = FileManager.default
        let pathComponent = url.appendingPathComponent("ER2")
        try! fileManager.createDirectory(atPath: pathComponent.path, withIntermediateDirectories: true, attributes: nil)
    }

    fileprivate func getPropertyList() -> URL? {
        let url = libraryFolder.url
        let pathComponent = url.appendingPathComponent("ER2")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            let pathComponent = pathComponent.appendingPathComponent("com.er2.applications.plist")
            let filePath = pathComponent.path
            if fileManager.fileExists(atPath: filePath) {
                return pathComponent
            } else {
                createLibraryFolder()
                return copyPlist()
            }

        } else {
            return copyPlist()
        }
    }

    fileprivate func copyPlist() -> URL! {
        let url = libraryFolder.url
        let pathComponent = url.appendingPathComponent("ER2").appendingPathComponent("com.er2.applications.plist")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: filePath) {
            let defaultPlist = Bundle.main.path(forResource: "com.er2.applications", ofType: "plist")
            try! fileManager.copyItem(atPath: defaultPlist!, toPath: filePath)
            return pathComponent
        } else {
            return pathComponent
        }

    }

    public func updatePreferences(_ keysAndValues: [String: String]) {
        guard let plistPath = self.getPropertyList()
            else {
                return
        }
        guard let preferences = NSMutableDictionary(contentsOf: plistPath)
            else {
                return
        }

        for key in keysAndValues.keys {
            preferences[key] = keysAndValues[key]
        }

        preferences.write(to: plistPath, atomically: true)
    }

    private func writePreferences() {
        guard let plistPath = self.getPropertyList()
            else {
                return
        }
        guard let preferences = NSMutableDictionary(contentsOf: plistPath)
            else {
                return
        }

        preferences.write(to: plistPath, atomically: true)
    }

    private func getHostInfo() -> [String]? {
        if(self.serverInfo == nil) {
            guard let plistPath = self.getPropertyList()
                else {
                    return nil
            }

            guard let preferences = NSDictionary(contentsOf: plistPath)
                else {
                    return nil
            }

            guard let serverIP = preferences["Server IP"] as? String
                else {
                    return nil
            }

            guard let serverPath = preferences["Server Path"] as? String
                else {
                    return nil
            }

            self.serverInfo = [serverIP, serverPath]
            return [serverIP, serverPath]
        } else {
            return self.serverInfo
        }
    }

    public func checkIfLoggingEnabled() -> Bool {
        if(getLoggingInfo() == nil) {
            remoteLoggingEnabled = false
        }
        return remoteLoggingEnabled
    }

    private func getLoggingInfo() -> [Any]? {
        if(self.loggingInfo == nil) {
            guard let plistPath = self.getPropertyList()
                else {
                    return nil
            }

            guard let preferences = NSDictionary(contentsOf: plistPath)
                else {
                    return nil
            }

            guard let checkForRemoteLogging = preferences["Logging Enabled"] as? Bool
                else {
                    return nil
            }

            remoteLoggingEnabled = checkForRemoteLogging

            guard let loggingURL = preferences["Logging URL"] as? String
                else {
                    return nil
            }

            guard let loggingPort = preferences["Logging Port"] as? UInt
                else {
                    return nil
            }

            self.loggingInfo = [loggingURL, loggingPort]
            return [loggingURL, loggingPort]
        } else {
            return self.loggingInfo
        }
    }

    public func getLoggingURL() -> String {
        guard let loggingInfo = self.getLoggingInfo()
            else {
                return "logs.papertrailapp.com"
        }

        return loggingInfo[0] as! String
    }

    public func getLoggingPort() -> UInt {
        guard let serverInfo = self.getLoggingInfo()
            else {
                return 1234
        }

        return serverInfo[1] as! UInt
    }

    public func getServerIP() -> String {
        guard let serverInfo = self.getHostInfo()
            else {
                return hostDiskServer
        }

        #if DEBUG
            return "127.0.0.1"
        #else
            return serverInfo[0]
        #endif
    }

    public func getMountPoint() -> String {
        #if DEBUG
            return "/var/tmp/TestInstallers"
        #else
            return "/var/tmp/Installers"
        #endif
    }

    public func getServerPath() -> String {
        guard let serverInfo = self.getHostInfo()
            else {
                return hostDiskPath
        }

        #if DEBUG
            return "/Users/keatonburleson/Documents/NFS"
        #else
            return serverInfo[1]
        #endif
    }

    public func raw() -> NSDictionary? {
        guard let plistPath = self.getPropertyList()
            else {
                return nil
        }
        guard let rawPreferences = NSDictionary(contentsOf: plistPath)
            else {
                return nil
        }

        return rawPreferences
    }

    public func getApplications() -> [String: [String: String]]? {
        guard let plistPath = self.getPropertyList()
            else {
                return nil
        }
        guard let preferences = NSDictionary(contentsOf: plistPath)
            else {
                return nil
        }

        guard let localSections = preferences["Applications"] as? [String: Any]
            else {
                return nil
        }

        for (title, applications) in localSections {
            sections[title] = applications as? [String: String]
        }

        return sections
    }


    private func constructLogger() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        let fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        
        DDLog.add(fileLogger)
        DDLog.add(DDOSLogger.sharedInstance)

        if(self.checkIfLoggingEnabled()) {
            let logger = RMPaperTrailLogger.sharedInstance()!

            logger.host = self.getLoggingURL()
            logger.port = self.getLoggingPort()
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
