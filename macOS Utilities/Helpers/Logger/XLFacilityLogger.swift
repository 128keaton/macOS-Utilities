//
//  XLFacilityLogger.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class XLFacilityLogger: DDAbstractLogger {
    override init() {
        let httpLogger = XLHTTPServerLogger()

        XLSharedFacility.removeAllLoggers()
        XLSharedFacility.addLogger(XLOverlayLog.shared)
        XLSharedFacility.addLogger(httpLogger)
        XLSharedFacility.minLogLevel = .logLevel_Verbose
    }

    override func log(message logMessage: DDLogMessage) {
        var message = logMessage.message

        let ivar = class_getInstanceVariable(object_getClass(self), "_logFormatter")
        if let formatter = object_getIvar(self, ivar!) as? DDLogFormatter {
            message = formatter.format(message: logMessage)!
        }

        switch logMessage.flag {
        case .error:
            XLSharedFacility.logMessage(message, withTag: nil, level: .logLevel_Error)
            break
        case .verbose:
            XLSharedFacility.logMessage(message, withTag: nil, level: .logLevel_Verbose)
            break
        default:
            XLSharedFacility.logMessage(message, withTag: nil, level: .logLevel_Info)
            break
        }


    }
}
