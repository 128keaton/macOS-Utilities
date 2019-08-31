//
//  NSApplication+Bugsnag.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/30/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Bugsnag

@objc(BSApplication)
class BSApplication: NSApplication {
    func reportException(exception: NSException) {
        Bugsnag.notify(exception)
        super.reportException(exception)
    }
}
