//
//  ExceptionHandler.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import ExceptionHandling
import CocoaLumberjack

class ExceptionHandler {
    static var hasExceptions: Bool {
        return exceptions.count > 0
    }
    
    static var exceptions: [ExceptionItem] {
        return getExceptions()
    }
    
    class func handle(exception: NSException) {
        var exceptions = [ExceptionItem]()
        if let items = UserDefaults.standard.array(forKey: "UncaughtExceptions") as? [Data] {
            for item in items {
                if let exception = NSKeyedUnarchiver.unarchiveObject(with: item) as? ExceptionItem {
                    exceptions.append(exception)
                }
            }
        }
        
        let newItem = ExceptionItem(exceptionDate: Date(), exception: exception)
        exceptions.insert(newItem, at: 0)
        if exceptions.count > 5 { // Only keep the last 5 exceptions
            exceptions = Array(exceptions[0..<5])
        }
        
        var items = [Data]()
        for e in exceptions {
            let item = NSKeyedArchiver.archivedData(withRootObject: e) as Data
            items.append(item)
        }
        UserDefaults.standard.set(items, forKey: "UncaughtExceptions")
    }
    
    public class func clearExceptions() {
        UserDefaults.standard.removeObject(forKey: "UncaughtExceptions")
    }
    
    private class func getExceptions() -> [ExceptionItem] {
        var exceptions = [ExceptionItem]()
        if let items = UserDefaults.standard.array(forKey: "UncaughtExceptions") as? [Data] {
            for item in items {
                if let exception = NSKeyedUnarchiver.unarchiveObject(with: item) as? ExceptionItem {
                    exceptions.append(exception)
                }
            }
        }
        
        return exceptions
    }
}
