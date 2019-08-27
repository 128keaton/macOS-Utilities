//
//  LoggerManager.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack
import PaperTrailLumberjack
import RainbowSwift

class LoggerManager {
    private static var loggerInitialized = false

    public static func constructLogger() {
        let fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1

        if loggerInitialized == false {
            DDLog.add(fileLogger)
            DDLog.add(ErrorAlertLogger())
            DDLog.add(DDOSLogger.sharedInstance)

            DDLogInfo(NSApplication.shared.getVerboseName())
            DDLogInfo("\n")
            DDLogInfo("\n---------------------------LOGGER INITIALIZED---------------------------".applyingCodes(Color.red, BackgroundColor.yellow, Style.bold))
            DDLogInfo("\n")
            loggerInitialized = true
            return
        }

        DDLogVerbose("Logger already initialized, not reinitializing.")
    }

    public static func constructRemoteLogger(loggingPreferences: LoggingPreferences, debugMode: Bool = false) {
        if(PreferenceLoader.currentPreferences != nil && PreferenceLoader.currentPreferences?.loggingPreferences?.loggingEnabled == true) {
            let logger = RMPaperTrailLogger.sharedInstance()!
            let systemUUID = NSApplication.shared.getSerialNumber() ?? NSApplication.shared.systemUUID ?? ""

            logger.debug = debugMode
            logger.host = loggingPreferences.loggingURL
            logger.port = loggingPreferences.loggingPort

            logger.machineName = Host.current().localizedName != nil && !(Host.current().localizedName?.contains("NetBoot"))! ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__\(systemUUID))") : String("\(Sysctl.model)__(\(systemUUID))")

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
