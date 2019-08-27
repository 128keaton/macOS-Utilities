//
//  ExceptionItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import ExceptionHandling

class ExceptionItem {
    public var exceptionDate: Date
    public var exception: NSException
    
    init(exceptionDate: Date, exception: NSException) {
        self.exceptionDate = exceptionDate
        self.exception = exception
    }
}
