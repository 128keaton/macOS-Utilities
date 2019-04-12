//
//  ErrorAlertLogger.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class ErrorAlertLogger: DDAbstractLogger {
    static let showErrorAlert = Notification.Name("NSShowErrorAlert")

    override func log(message logMessage: DDLogMessage) {
        var message = logMessage.message

        let ivar = class_getInstanceVariable(object_getClass(self), "_logFormatter")
        if let formatter = object_getIvar(self, ivar!) as? DDLogFormatter {
            message = formatter.format(message: logMessage)!
        }

        if logMessage.flag == .error {
            #if !DEBUG
                NotificationCenter.default.post(name: ErrorAlertLogger.showErrorAlert, object: message)
            #endif
        }
    }
}
