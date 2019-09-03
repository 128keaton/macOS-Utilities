//
//  ExceptionItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import ExceptionHandling

class ExceptionItem: NSObject, NSCoding {
    func encode(with aCoder: NSCoder) {
        aCoder.encode(exceptionDate, forKey: "exceptionDate")
        aCoder.encode(exception, forKey: "exception")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.exceptionDate = aDecoder.decodeObject(forKey: "exceptionDate") as! Date
        self.exception = aDecoder.decodeObject(forKey: "exception") as! NSException
    }
    
    public var exceptionDate: Date
    public var exception: NSException
    
    init(exceptionDate: Date, exception: NSException) {
        self.exceptionDate = exceptionDate
        self.exception = exception
    }
}
