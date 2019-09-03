//
//  Size.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class Size {
    /// Returns a double based on passed string value. i.e. 1 GB = 1,099,511,627,776.0 (bytes)
    static func rawValue(_ stringValue: String) -> Double {
        guard let doubleValue = Double(stringValue.filter("01234567890.".contains))?.rounded() else {
            return 0.0
        }
        
        if stringValue.contains("TB") {
            return (pow(1024, 4) * doubleValue).rounded()
        } else if stringValue.contains("GB") {
            return (pow(1024, 3) * doubleValue).rounded()
        } else if stringValue.contains("MB") {
            return (pow(1024, 2) * doubleValue).rounded()
        }
        
        return (1024 * doubleValue).rounded()
    }
}
