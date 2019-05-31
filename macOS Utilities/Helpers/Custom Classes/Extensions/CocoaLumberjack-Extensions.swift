//
//  CocoaLumberjack-Extensions.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

public func KBLogDebug(_ message: @autoclosure () -> String, level: DDLogLevel = DDDefaultLogLevel, context: Int = 0,  file: StaticString = #file, function: StaticString = #function, line: UInt = #line, tag: Any? = nil, asynchronous async: Bool = asyncLoggingEnabled, ddlog: DDLog = .sharedInstance) {
    #if DEBUG
        _DDLogMessage(message(), level: level, flag: .debug, context: context, file: file, function: function, line: line, tag: tag, asynchronous: async, ddlog: ddlog)
    #endif
}
